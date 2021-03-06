/* Copyright Daniel Lobo, aka Peixoto:
 * dabo.loniel@gmail.com
 */

InstallHook(hook_function_name, byref function2hook, dll = "", function2hook_name = "" ,callback_options = "F") {
	/*Errors
		1: Failed to get the adress of the dll or sethook function (Unlikelly)
		2: Failed to register the callback for the hook function
		3: Failed to load the specified libray with lasterror = 126 (the especified module
		could not be found(remember that module names are case sensitive)
		4: Failed to load the specified libray with another error code
		5: Failed to get the adress of the function to be hooked (these names are also case sensitive)

		6: detour error calling DetourAttach ERROR_INVALID_HANDLE: "The ppPointer parameter is
		null or points to a null pointer".  if you are getting the pointer to the funtion to be
		detoured yourself, you are most likely not getting a valid pointer
		8: detour error calling DetourAttach or DetourUpdateThread ERROR_NOT_ENOUGH_MEMORY
		9: detour error calling DetourAttach ERROR_INVALID_BLOCK: "The function referenced is too
		small to be detoured".
		13: detour error calling DetourTransactionCommit ERROR_INVALID_DATA: "Target function was changed
		by third party between steps of the transaction".
		4317: detour error calling DetourTransactionBegin(Most Likely), DetourAttach or
		DetourTransactionCommit: ERROR_INVALID_OPERATION: "A pending transaction alredy exists".
		Probably a previous call to sethook did not complete and let a transaction opened.
	*/

	static hdtrs = "", sethooks = ""
	if not hdtrs
		{
			hdtrs  := dllcall("GetModuleHandle", "str", "peixoto.dll")
			sethooks := dllcall("GetProcAddress", "int", hdtrs , "astr", "sethook")
		}

	if not hdtrs  or not sethooks
		return 1

	if hook_function_name is Number
		 hook_function := hook_function_name
	else hook_function := RegisterCallback(hook_function_name, callback_options)
	if not hook_function
		return 2

	if ! (dll = "")
		{
			hdll := dllcall("LoadLibrary", str, dll)
			if not hdll
				{
					if (A_lasterror = 126)
						return 3
					else return 4
				}
				function2hook := dllcall("GetProcAddress", "int", hdll, "astr", function2hook_name)

			if not function2hook
				return 5
		}

	return  dllcall(sethooks, "Ptr*", function2hook, "Ptr", hook_function)
}

InstallComHook(pInterface, byref pHooked, hook_name, offset, release = True) {
	/*Errors
		1: Failed to get the adress of the dll or sethook function (Unlikelly)
		2: Failed to register the callback for the hook function
		6: detour error calling DetourAttach ERROR_INVALID_HANDLE: "The ppPointer parameter is
		null or points to a null pointer".  if you are getting the pointer to the funtion to be
		detoured yourself, you are most likely not getting a valid pointer
		8: detour error calling DetourAttach or DetourUpdateThread ERROR_NOT_ENOUGH_MEMORY
		9: detour error calling DetourAttach ERROR_INVALID_BLOCK: "The function referenced is too
		small to be detoured".
		13: detour error calling DetourTransactionCommit ERROR_INVALID_DATA: "Target function was changed
		by third party between steps of the transaction".
		4317: detour error calling DetourTransactionBegin(Most Likely), DetourAttach or
		DetourTransactionCommit: ERROR_INVALID_OPERATION: "A pending transaction alredy exists".
		Probably a previous call to sethook did not complete and let a transaction opened.
	*/

	static hdtrs = "", sethooks = ""
	if not hdtrs
		{
			hdtrs  := dllcall("GetModuleHandle", "str", "peixoto.dll")
			sethooks := dllcall("GetProcAddress", "int", hdtrs , "astr", "sethook")
		}

	if not hdtrs  or not sethooks
		return 1

	pInterface_Vtbl := numget(pInterface+0, "Ptr")
	pHooked := numget(pInterface_Vtbl + offset, "Ptr")

	pHook := registerCallback(hook_name)
	if not pHook
		return 2

	if release
		dllcall(numget(pInterface_Vtbl + 8), "Ptr", pInterface)	; release the interface

	return dllcall(sethooks, "Ptr*", pHooked , "Ptr", pHook)
}

ReleaseHooks() {
	/*  Unhooking never realy failed with me so it's hard to say how error handling will behave,
		maybe the app will just crash. In anycase, if it fails but doesn't crash the function
		should return [index of the operation that failed, error] if it fails before calling the
		dll function the index is -2

		Errors:
		-1:(index) No hook was set before trying to release them
		-2:(index) Failed to get the adress of the intruder dll or reload function (Unlikelly)

		6: detour error calling DetourDetach ERROR_INVALID_HANDLE: "The ppPointer parameter is
		null or points to a null pointer".  Unlikely because the dll stores the pointer of
		sucessful operations
		8: detour error calling DetourDetach or DetourUpdateThread ERROR_NOT_ENOUGH_MEMORY
		9: detour error calling DetourDetach ERROR_INVALID_BLOCK: "The function referenced is too
		small to be detoured".
		13: detour error calling DetourTransactionCommit ERROR_INVALID_DATA: "Target function was changed
		by third party between steps of the transaction".
		4317: detour error calling DetourTransactionBegin(Most Likely), DetourDetach or
		DetourTransactionCommit: ERROR_INVALID_OPERATION: "A pending transaction alredy exists".
		Probably a previous call to sethook did not complete and let a transaction opened.
	*/
	static hdll = "", release = ""
	if not hdll
		{
			hdll  := dllcall("GetModuleHandle", "str", "peixoto.dll")
			release := dllcall("GetProcAddress", "int", hdll, "astr", "ReleaseAllHooks")
		}

	if not hdll or not release
		return [-2, 0]

	varsetcapacity(err, 4, 0)
	index := dllcall(release, "int*", &err)
	return [index, numget(err, 0, "int")]
}

redirectCall(_add, _func, options = "F") {
	callBack := RegisterCallback(_func, options)
	VarSetCapacity(offset, 4)
	numput(callBack - (_add + 5), &offset+0, "int")

	;printl("callBack " callBack " " callBack - (_add + 5))
	if not dllcall("VirtualProtect", uint, _add, uint, 4, uint, (PAGE_READWRITE := 0x04), "uint*", old_protect)
		return
	loop, 4
		numput(numget(&offset + A_index - 1, "uchar"), _add + A_index, "uchar")
	dllcall("VirtualProtect", uint, _add, uint, 4, uint, old_protect, "uint*", dummy)
	return callBack
}

redirectCallD(_add, _func, options = "F") {
	callBack := RegisterCallback(_func, options)
	VarSetCapacity(offset, 4)
	numput(callBack - (_add + 5), &offset+0, "int")

	static hdtrs = "", sethooks = ""
	if not hdtrs
		{
			hdtrs  := dllcall("GetModuleHandle", "str", "peixoto.dll")
			sethooks := dllcall("GetProcAddress", "int", hdtrs , "astr", "sethook")
		}

	if not hdtrs  or not sethooks
		return 1

	return dllcall(sethooks, "Ptr*", _add, "Ptr", callBack)
}

getModulePath(exe = "") {
	A_isDll ? hModule := A_ModuleHandle : hModule := dllcall("GetModuleHandle", uint, 0)
	exe ? hModule := dllcall("GetModuleHandle", uint, 0)
	VarSetCapacity(buff, 260 * 2)
	size := dllcall("GetModuleFileName", uint, hModule, ptr, &buff, int, 260 * 2)
	return strget(&buff, "UTF-16")
}

getModuleName(exe = True) {
	path := getModulePath(exe)
	splitpath, path, filename
	return filename
}

ahkHookGetScript(resource = "", module = "") {
	if ( (not A_iscompiled) and (not module) )
	{
		fileread, script, %A_scriptfullpath%
		return script
	}

	resource ? resource := ">AUTOHOTKEY SCRIPT<"

	if module
	{
		splitpath, module, , , ext,
		if (ext = "ahk")
		{
			fileread, script, %module%
			return script
		}
		else hModule := dllcall("LoadLibraryW", str, module)
	}
	else hModule := dllcall("GetModuleHandle", uint,  0)

	HRSRC := dllcall("FindResourceW", uint, hModule, str, resource, ptr, 10)
	if ( (HRSRC = 0) and (resource = ">AUTOHOTKEY SCRIPT<") )
		return ahkHookGetScript(">AHK WITH ICON<")

	hResource := dllcall("LoadResource", uint, hModule, uint, HRSRC)
	DataSize := DllCall("SizeofResource", ptr, hModule, ptr, HRSRC, uint)
	pResData := dllcall("LockResource", uint, hResource, ptr)
	return strget(pResData, DataSize, "UTF-8")
}


