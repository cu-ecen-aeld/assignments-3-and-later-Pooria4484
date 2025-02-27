#include "unity.h"
#include <stdbool.h>
#include <stdlib.h>
#include "../../examples/autotest-validate/autotest-validate.h"
#include "../../assignment-autotest/test/assignment1/username-from-conf-file.h"

void test_validate_my_username()
{
    // Get the hardcoded username from my_username()
    const char* hardcoded_username = my_username();
    
    // Get the username from the config file
    char* config_username = malloc_username_from_conf_file();
    
    // Verify the strings are equal
    TEST_ASSERT_EQUAL_STRING_MESSAGE(
        hardcoded_username, 
        config_username, 
        "Username from config file does not match hardcoded username!"
    );
    
    // Free the allocated memory from malloc_username_from_conf_file()
    if (config_username != NULL) {
        free(config_username);
    }
}