#include <windows.h>

extern FARPROC real_game_main;
extern HMODULE game_dll_base;

typedef int (__stdcall *game_main_fn)(HMODULE);

__declspec(dllexport) int __stdcall GameMain(HMODULE ignored)
{
    (void)ignored;
    return ((game_main_fn)real_game_main)(game_dll_base);
}
