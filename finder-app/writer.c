#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <syslog.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>

int main(int argc, char *argv[])
{
    // Open syslog with LOG_USER facility
    openlog("writer", LOG_PID | LOG_CONS, LOG_USER);
    
    // Check if exactly 2 arguments are provided (plus program name = 3 total)
    if (argc != 3) {
        syslog(LOG_ERR, "Invalid number of arguments: %d, expected 2", argc - 1);
        fprintf(stderr, "Error: Two arguments are required\n");
        fprintf(stderr, "Usage: %s <full_path_to_file> <text_string>\n", argv[0]);
        closelog();
        return 1;
    }

    const char *writefile = argv[1];
    const char *writestr = argv[2];

    // Log the intended operation at DEBUG level
    syslog(LOG_DEBUG, "Writing %s to %s", writestr, writefile);

    // Open the file for writing (create if doesn't exist, truncate if it does)
    int fd = open(writefile, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd == -1) {
        syslog(LOG_ERR, "Failed to open file %s: %s", writefile, strerror(errno));
        fprintf(stderr, "Error: Could not open file '%s': %s\n", writefile, strerror(errno));
        closelog();
        return 1;
    }

    // Write the string to the file
    ssize_t bytes_to_write = strlen(writestr);
    ssize_t bytes_written = write(fd, writestr, bytes_to_write);
    if (bytes_written == -1) {
        syslog(LOG_ERR, "Failed to write to file %s: %s", writefile, strerror(errno));
        fprintf(stderr, "Error: Could not write to file '%s': %s\n", writefile, strerror(errno));
        close(fd);
        closelog();
        return 1;
    }

    // Check if all bytes were written
    if (bytes_written != bytes_to_write) {
        syslog(LOG_ERR, "Incomplete write to %s: wrote %zd of %zd bytes", 
               writefile, bytes_written, bytes_to_write);
        fprintf(stderr, "Error: Incomplete write to '%s'\n", writefile);
        close(fd);
        closelog();
        return 1;
    }

    // Add a newline (consistent with writer.sh's echo behavior)
    if (write(fd, "\n", 1) != 1) {
        syslog(LOG_ERR, "Failed to write newline to %s: %s", writefile, strerror(errno));
        fprintf(stderr, "Error: Could not write newline to '%s': %s\n", writefile, strerror(errno));
        close(fd);
        closelog();
        return 1;
    }

    // Clean up and exit
    if (close(fd) == -1) {
        syslog(LOG_ERR, "Failed to close file %s: %s", writefile, strerror(errno));
        fprintf(stderr, "Error: Could not close file '%s': %s\n", writefile, strerror(errno));
        closelog();
        return 1;
    }

    closelog();
    return 0;
}