#ifndef MACROS_INC
#define MACROS_INC

#macro assert(condition, message_if_failed)
    #if eval((condition) < 1)
        #define errmsg eval(message_if_failed)
        #define err "Assert failed: ", errmsg
        .error err
    #endif
#endmacro
#macro relocate(newloc)
    #ifdef APP_RELOCATE_OLD
        .error "You may not nest relocate() blocks."
    #else
        #define APP_RELOCATE_OLD eval($)
        .org newloc
        #define APP_RELOCATE_NEW eval(newloc)
    #endif
#endmacro
#macro endrelocate()
    #ifndef APP_RELOCATE_NEW
        .error "You need to start a relocate() block before ending it."
    #else
        .org $ - APP_RELOCATE_NEW + APP_RELOCATE_OLD
        #undef APP_RELOCATE_NEW
        #undef APP_RELOCATE_OLD
    #endif
#endmacro


#define .assert(cond,msg) assert(cond,msg)
#define .relocate(newloc) relocate(newloc)
#define .endrelocate() endrelocate()

#endif MACROS_INC
