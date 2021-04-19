#include "Test.h"
#include <stdlib.h>

#pragma GCC push_options
#pragma GCC optimize ("O2", "omit-frame-pointer")
__attribute__((noinline)) static void* foo(size_t x)
{
    return malloc(x);  
}
#pragma GCC pop_options

int main()
{
    if(*(short*)&foo != 0x60FF)
    {
        TEST_LOG_NO();
        return 0;
    }

    uint32_t offset = *(uint32_t*) ((char*)&foo + 2);
    if(((char*)&foo + 2) + offset != (char*)&malloc)
    {
        TEST_LOG_NO();
        return 0;
    }

    char *p = foo(42);
    strcpy(p, "OK");
    TestLog(p);
    free(p);
    return 0;
}
