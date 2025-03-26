#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <syslog.h>
#include <signal.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/select.h>
#include <sys/stat.h>
#include <sys/types.h>

#define PORT 9000
#define DATA_FILE "/var/tmp/aesdsocketdata"
#define BUFFER_SIZE 1024

static volatile sig_atomic_t keep_running = 1;

void signal_handler(int sig) {
    keep_running = 0;
    syslog(LOG_INFO, "Caught signal, exiting");
}

int daemonize() {
    pid_t pid = fork();
    
    if (pid < 0) {
        syslog(LOG_ERR, "Fork failed: %s", strerror(errno));
        return -1;
    }
    
    if (pid > 0) {
        // Parent process exits
        exit(0);
    }
    
    // Child process continues
    if (setsid() < 0) {
        syslog(LOG_ERR, "setsid failed: %s", strerror(errno));
        return -1;
    }
    
    // Change working directory to root
    if (chdir("/") < 0) {
        syslog(LOG_ERR, "chdir failed: %s", strerror(errno));
        return -1;
    }
    
    // Redirect standard file descriptors
    close(STDIN_FILENO);
    close(STDOUT_FILENO);
    close(STDERR_FILENO);
    
    int fd = open("/dev/null", O_RDWR);
    if (fd != -1) {
        dup2(fd, STDIN_FILENO);
        dup2(fd, STDOUT_FILENO);
        dup2(fd, STDERR_FILENO);
        if (fd > 2) close(fd);
    }
    
    return 0;
}

int main(int argc, char *argv[]) {
    int server_fd, client_fd;
    struct sockaddr_in server_addr, client_addr;
    socklen_t client_len = sizeof(client_addr);
    char buffer[BUFFER_SIZE];
    char client_ip[INET_ADDRSTRLEN];
    int daemon_mode = 0;
    
    // Check for -d argument
    if (argc > 1 && strcmp(argv[1], "-d") == 0) {
        daemon_mode = 1;
    }
    
    // Setup signal handlers
    struct sigaction sa;
    sa.sa_handler = signal_handler;
    sa.sa_flags = 0;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGINT, &sa, NULL);
    sigaction(SIGTERM, &sa, NULL);
    
    // Open syslog
    openlog("aesdsocket", LOG_PID, LOG_USER);
    
    // Create socket
    if ((server_fd = socket(AF_INET, SOCK_STREAM, 0)) == -1) {
        syslog(LOG_ERR, "Socket creation failed: %s", strerror(errno));
        return -1;
    }
    
    // Allow port reuse
    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    
    // Configure server address
    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = INADDR_ANY;
    server_addr.sin_port = htons(PORT);
    
    // Bind socket
    if (bind(server_fd, (struct sockaddr*)&server_addr, sizeof(server_addr)) == -1) {
        syslog(LOG_ERR, "Bind failed: %s", strerror(errno));
        close(server_fd);
        return -1;
    }
    
    // Listen for connections
    if (listen(server_fd, 5) == -1) {
        syslog(LOG_ERR, "Listen failed: %s", strerror(errno));
        close(server_fd);
        return -1;
    }
    
    // Daemonize after successful bind if requested
    if (daemon_mode) {
        if (daemonize() < 0) {
            close(server_fd);
            return -1;
        }
    }
    
    while (keep_running) {
        fd_set readfds;
        struct timeval tv;
        
        tv.tv_sec = 1;
        tv.tv_usec = 0;
        
        FD_ZERO(&readfds);
        FD_SET(server_fd, &readfds);
        
        int ready = select(server_fd + 1, &readfds, NULL, NULL, &tv);
        
        if (!keep_running) {
            break;
        }
        
        if (ready <= 0) {
            continue;
        }
        
        client_fd = accept(server_fd, (struct sockaddr*)&client_addr, &client_len);
        if (client_fd == -1) {
            syslog(LOG_ERR, "Accept failed: %s", strerror(errno));
            continue;
        }
        
        inet_ntop(AF_INET, &client_addr.sin_addr, client_ip, INET_ADDRSTRLEN);
        syslog(LOG_INFO, "Accepted connection from %s", client_ip);
        
        FILE *fp = fopen(DATA_FILE, "a+");
        if (!fp) {
            syslog(LOG_ERR, "Failed to open data file: %s", strerror(errno));
            close(client_fd);
            continue;
        }
        
        ssize_t bytes_received;
        while ((bytes_received = recv(client_fd, buffer, BUFFER_SIZE - 1, 0)) > 0) {
            buffer[bytes_received] = '\0';
            
            char *ptr = buffer;
            char *newline;
            
            while ((newline = strchr(ptr, '\n')) != NULL) {
                *newline = '\0';
                fprintf(fp, "%s\n", ptr);
                fflush(fp);
                
                rewind(fp);
                while (fgets(buffer, BUFFER_SIZE, fp) != NULL) {
                    send(client_fd, buffer, strlen(buffer), 0);
                }
                
                ptr = newline + 1;
            }
            
            if (ptr < buffer + bytes_received) {
                fprintf(fp, "%s", ptr);
                fflush(fp);
            }
        }
        
        fclose(fp);
        syslog(LOG_INFO, "Closed connection from %s", client_ip);
        close(client_fd);
    }
    
    close(server_fd);
    remove(DATA_FILE);
    closelog();
    
    return 0;
}
