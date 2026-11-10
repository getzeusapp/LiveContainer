//
//  SimulatorStubs.m
//  LiveContainer
//
//  Stand-ins for the parts of zContainer that run guest apps, in the iOS
//  Simulator on an Intel Mac. There they can't build, being ARM through and
//  through, so xcconfigs/Simulator.xcconfig leaves out litehook.c,
//  dyld_bypass_validation.m and Tweaks/Dyld.m. The Simulator only runs
//  zContainer's own interface, with no guest apps, so nothing here is called
//  for real: launching a guest stops before it would be. Everywhere else this
//  file is empty.
//

#include <TargetConditionals.h>

#if TARGET_OS_SIMULATOR && defined(__x86_64__)

#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <mach/mach.h>
#include "../../litehook/src/litehook.h"

#pragma mark - litehook.c

uint32_t gRebindCount = 0;
global_rebind *gRebinds = NULL;

const char *litehook_locate_dsc(void) {
    return NULL;
}

void *litehook_find_symbol(const mach_header_u *header, const char *symbolName) {
    return NULL;
}

void *litehook_find_symbol_file(const mach_header_u *header, const char *symbolName) {
    return NULL;
}

void *litehook_find_dsc_symbol(const char *imagePath, const char *symbolName) {
    return NULL;
}

kern_return_t litehook_hook_function(void *source, void *target) {
    return KERN_NOT_SUPPORTED;
}

void litehook_rebind_symbol(const mach_header_u *targetHeader, void *replacee, void *replacement, bool (*exceptionFilter)(const mach_header_u *header)) {
}

// TPRO only exists on ARM devices, so the system has none of these here.

bool os_tpro_is_supported(void) {
    return false;
}

void os_thread_self_restrict_tpro_to_rw(void) {
}

void os_thread_self_restrict_tpro_to_ro(void) {
}

#pragma mark - dyld_bypass_validation.m

void init_bypassDyldLibValidation(void) {
}

void searchDyldFunctions(void) {
}

char *searchDyldFunction(char *base, char *signature, int length) {
    return NULL;
}

kern_return_t builtin_vm_protect(mach_port_name_t task, mach_vm_address_t address, mach_vm_size_t size, boolean_t set_max, vm_prot_t new_prot) {
    return vm_protect(task, (vm_address_t)address, (vm_size_t)size, set_max, new_prot);
}

#pragma mark - Tweaks/Dyld.m

uint32_t appMainImageIndex = 0;
void *appExecutableHandle = NULL;
bool tweakLoaderLoaded = false;

void DyldHooksInit(bool hideLiveContainer, bool hookDlopen, uint32_t spoofSDKVersion) {
}

void DyldHookLoadableIntoProcess(void) {
}

bool performHookDyldApi(const char *functionName, uint32_t adrpOffset, void **origFunction, void *hookFunction) {
    return false;
}

void *getGuestAppHeader(void) {
    return NULL;
}

void *getDSCAddr(void) {
    return NULL;
}

void *getCachedSymbol(NSString *symbolName, struct mach_header_64 *header) {
    return NULL;
}

void saveCachedSymbol(NSString *symbolName, struct mach_header_64 *header, uint64_t offset) {
}

void *dlopen_nolock(const char *path, int mode) {
    return dlopen(path, mode);
}

void bypass_seg_count_check(void (^block)(void)) {
    block();
}

void bypass_os_variant_has_internal_content(void (^block)(void)) {
    block();
}

// mach_excServer.c's handlers, for the exceptions Dyld.m catches.

kern_return_t catch_mach_exception_raise(mach_port_t exception_port, mach_port_t thread, mach_port_t task, exception_type_t exception, mach_exception_data_t code, mach_msg_type_number_t codeCnt) {
    return KERN_FAILURE;
}

kern_return_t catch_mach_exception_raise_state(mach_port_t exception_port, exception_type_t exception, const mach_exception_data_t code, mach_msg_type_number_t codeCnt, int *flavor, const thread_state_t old_state, mach_msg_type_number_t old_stateCnt, thread_state_t new_state, mach_msg_type_number_t *new_stateCnt) {
    return KERN_FAILURE;
}

kern_return_t catch_mach_exception_raise_state_identity(mach_port_t exception_port, mach_port_t thread, mach_port_t task, exception_type_t exception, mach_exception_data_t code, mach_msg_type_number_t codeCnt, int *flavor, thread_state_t old_state, mach_msg_type_number_t old_stateCnt, thread_state_t new_state, mach_msg_type_number_t *new_stateCnt) {
    return KERN_FAILURE;
}

#endif
