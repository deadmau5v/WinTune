CheckUninstallOneDrive() {
	OneDriveSetup:=A_WinDir "\System32\OneDriveSetup.exe"
	If !FileExist(OneDriveSetup) {	
		OneDriveSetup:=A_WinDir "\SysWOW64\OneDriveSetup.exe"
		If !FileExist(OneDriveSetup) {
			OneDriveSetup:=A_WinDir "\Sysnative\OneDriveSetup.exe"
			If !FileExist(OneDriveSetup)
				Return -1
		}
	}
	OneDriveSetupRun:=RegRead(HKCU "\Software\Microsoft\Windows\CurrentVersion\RunOnce", "OneDriveSetup", "")
	PreInstall:=!InStr(OneDriveSetupRun, "/uninstall")
	If !(OneDriveExist:=FileExist(EnvGet2("Local AppData") "\Microsoft\OneDrive\onedrive.exe")) {
		If !(OneDriveExist:=FileExist(A_ProgramFiles "\Microsoft OneDrive\OneDrive.exe")) && A_Is64bitOS {
				OneDriveExist:=FileExist(EnvGet("ProgramFiles(x86)") "\Microsoft OneDrive\OneDrive.exe")
		}
	}
	r:=0
	If (!OneDriveExist && !OneDriveSetupRun) || (OneDriveExist && OneDriveSetupRun && !PreInstall)
		r:=1
	Return r
}
UninstallOneDrive(s,d,silent) {
	OneDriveSetup:=A_WinDir "\System32\OneDriveSetup.exe"
	If !FileExist(OneDriveSetup) {	
		OneDriveSetup:=A_WinDir "\SysWOW64\OneDriveSetup.exe"
		If !FileExist(OneDriveSetup) {
			OneDriveSetup:=A_WinDir "\Sysnative\OneDriveSetup.exe"
			If !FileExist(OneDriveSetup)
				Return -1
		}
	}
	If !(IsPerMachine:=!!FileExist(A_ProgramFiles "\Microsoft OneDrive\OneDrive.exe")) && A_Is64bitOS {
		IsPerMachine:=!!FileExist(EnvGet("ProgramFiles(x86)") "\Microsoft OneDrive\OneDrive.exe")
	}
	OneDriveSetupCMD:=OneDriveSetup (IsPerMachine?' /allusers':'') (s?' /uninstall':'') ' /silent'
	If CurrentUser=GetActiveUser() {
		If s
			ProcessClose "OneDrive.exe"
		RunWait OneDriveSetupCMD
	} Else {
		try
			RegDelete HKCU "\Software\Microsoft\Windows\CurrentVersion\Run", "OneDriveSetup"
		try
			RegDelete HKCU "\Software\Microsoft\Windows\CurrentVersion\Run", "OneDrive"
		RegWrite OneDriveSetupCMD, "REG_SZ", HKCU "\Software\Microsoft\Windows\CurrentVersion\RunOnce", "OneDriveSetup"
	}
}

CheckDisableVisualStudioTelemetry() {
	If FileExist(A_Is64bitOS?EnvGet("ProgramFiles(x86)"):A_ProgramFiles "\Microsoft Visual Studio\Installer\vswhere.exe")	
		Return RegRead(HKCU  "\Software\Microsoft\VisualStudio\Telemetry", "TurnOffSwitch",0)
	Else {
		Return -1
	}
}
DisableVisualStudioTelemetry(s,d,silent) {
	Ver:=SubStr(RunTerminal(A_Is64bitOS?EnvGet("ProgramFiles(x86)"):A_ProgramFiles "\Microsoft Visual Studio\Installer\vswhere.exe -latest -property catalog_productDisplayVersion"), 1,2)
	RegWrite s, "REG_DWORD", HKCU  "\Software\Microsoft\VisualStudio\Telemetry", "TurnOffSwitch"
	RegWrite !s, "REG_DWORD", "HKLM\Software\WOW6432Node\Microsoft\VSCommon\" Ver ".0\SQM", "OptIn"
	RegWrite !s, "REG_DWORD", HKCU "\Software\Microsoft\VSCommon\" Ver ".0\SQM", "OptIn"
}

CheckDisableSystemRestore() {
	Return !RegRead("HKLM\Software\Microsoft\Windows NT\CurrentVersion\SystemRestore", "RPSessionInterval",0)
}
DisableSystemRestore(s,d,silent) {
	If s {
		RegWrite '0', "REG_DWORD", "HKLM\Software\Microsoft\Windows NT\CurrentVersion\SystemRestore", "RPSessionInterval"
		RegDelete "HKLM\Software\Microsoft\Windows NT\CurrentVersion\SPP\Clients", "{09F7EDC5-294E-4180-AF6A-FB0E6A0E9513}"
		RunTerminal(A_Comspec ' /c vssadmin delete shadows /all /quiet')
	} Else {
		RegWrite '1', "REG_DWORD", "HKLM\Software\Microsoft\Windows NT\CurrentVersion\SystemRestore", "RPSessionInterval"
		DeviceID:=""
		For CS in ComObjGet("winmgmts:").ExecQuery("SELECT DeviceID FROM Win32_Volume WHERE DriveLetter='" SubStr(A_WinDir, 1, 2) "'") {
			DeviceID:=CS.DeviceID
		}
		RegExMatch(DeviceID, "\\?\\(.*)", &SubPat)
		RegWrite Trim(SubPat[0]) ":" DriveGetLabel(SubStr(A_WinDir, 1, 2)) "(" SubStr(A_WinDir, 1, 1) "%3A)", "REG_MULTI_SZ", "HKLM\Software\Microsoft\Windows NT\CurrentVersion\SPP\Clients", "{09F7EDC5-294E-4180-AF6A-FB0E6A0E9513}"
	}
}

CheckDisableMSDefender(*) {
	; SafeBootMode:=SysGet(67)
	If !SysGet(67) {
		try {
			service:= ComObject("Schedule.Service")
			service.Connect()
			location:=service.GetFolder("\Microsoft\Windows\Windows Defender")		
			If location.GetTask("Windows Defender Cache Maintenance").Enabled
				Return 0
			If location.GetTask("Windows Defender Cleanup").Enabled
				Return 0
			If location.GetTask("Windows Defender Scheduled Scan").Enabled
				Return 0
			If location.GetTask("Windows Defender Verification").Enabled
				Return 0
		} Catch {
			Return -1
		}
	}
	try {
		If (SS:=Service_State("Sense")) && SS = 4
			Return 0
		If (SS:=Service_State("WdBoot")) && SS = 4
			Return 0
		If (SS:=Service_State("WdFilter")) && SS = 4
			Return 0
		If (SS:=Service_State("WdNisDrv")) && SS = 4
			Return 0
		If (SS:=Service_State("WdNisSvc")) && SS = 4
			Return 0
		If (SS:=Service_State("WinDefend")) && SS = 4
			Return 0
		Return 1
	} Catch {
		Return -1
	}
}
DisableMSDefenderScheduleTask(s) {
	service:= ComObject("Schedule.Service")
	service.Connect()
	location:=service.GetFolder("\Microsoft\Windows\Windows Defender")
	location.GetTask("Windows Defender Cache Maintenance").Enabled:=!s
	location.GetTask("Windows Defender Cleanup").Enabled:=!s
	location.GetTask("Windows Defender Scheduled Scan").Enabled:=!s
	location.GetTask("Windows Defender Verification").Enabled:=!s
}
DisableMSDefenderService(s) {
	regpath:='HKLM\SYSTEM\CurrentControlSet\Services\'
	If s {
		try {
			RegRead(regpath "Sense", "Start")
			RegWrite '4', "REG_DWORD", regpath "Sense", "Start"
		}
		RegWrite '4', "REG_DWORD", regpath "WdBoot", "Start"
		RegWrite '4', "REG_DWORD", regpath "WdFilter", "Start"
		RegWrite '4', "REG_DWORD", regpath "WdNisDrv", "Start"
		RegWrite '4', "REG_DWORD", regpath "WdNisSvc", "Start"
		RegWrite '4', "REG_DWORD", regpath "WinDefend", "Start"
	} Else {
		try {
			RegRead(regpath "Sense", "Start")
			RegWrite '3', "REG_DWORD", regpath "Sense", "Start"
		}
		RegWrite '0', "REG_DWORD", regpath "WdBoot", "Start"
		RegWrite '0', "REG_DWORD", regpath "WdFilter", "Start"
		RegWrite '3', "REG_DWORD", regpath "WdNisDrv", "Start"
		RegWrite '3', "REG_DWORD", regpath "WdNisSvc", "Start"
		RegWrite '2', "REG_DWORD", regpath "WinDefend", "Start"
	}
	
}
RunDisableMSDefender(s) {
	DisableMSDefenderScheduleTask(s)
	RegWrite A_ScriptFullPath ' /DisableMSDefenderService=' s, "REG_SZ", "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\RunOnce", "*DisableMSDefenderService"
	Sleep 1000
	GoSafeboot()
}
RunDisableMSDefenderSafeMode(s) {
	DisableMSDefenderService(s)
	RegWrite A_ScriptFullPath ' /DisableMSDefenderScheduleTask=' s, "REG_SZ", "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\RunOnce", "*DisableMSDefenderScheduleTask"
	Sleep 1000
	ExitSafeboot()
}
DisableMSDefender(s,d,silent){
	SafeBootMode:=SysGet(67)
	n:=SafeBootMode?"SafeMode":""
	If silent {
		RunDisableMSDefender%n%(s)
	} Else {
		HideToolTip()
		Result := MsgBox(GetLangText("Text_DisableMSDefender" s), App.Name, "YesNo Icon?")
		if Result = "Yes" {
			RunDisableMSDefender%n%(s)
		} Else {
			Return !s
		}
	}
}

BtnClearStartMenu_Click(Ctr, *) {
	If VerCompare(A_OSVersion,"10.0.22000")>=0 {
		StartBin:="E27AE14B01FC4D1B9C00810BDE6E51854E5A5F47005BB1498A5C92AF9084F95ED76A61CE8F3CDA01200D00005CF6EE792CDF05E1BA2B6325C41A5F10E7E459FAA111B337AA5218595C3BDC8D317AAE0769ADAB884CBA8F80C54C6D265B46C2CDFCEE6E32348B12BEA7598230B0C26464C9D9C99AE14773EE81485428E603AB0C92098EBF08F90BFCEA33FF98F64768705911AA73B66C2710C53350D6A1F8D48868C3527CBE63C523A3092741568F61AA343C2E1BCA02846DE66A0AA46F4A03DA952739DCE16A0A1D851F2773974F5F0A16A8B37F3942F178D040C48123BC53DFDD9ED01E3542F0BAE6418BB06459220E9963759787BE4D96ED4895F09FE108340261447C8248D7A4BB6D5DB30F9C3282E8ACC2A746684930BBC4F8209D80D28868FA3F2AB8B3BDAD7E6CCB08F1B4A457F0B16824CB5E875BFCDB81602B081D8D6C4EF6F048144D30FBDC730E3744909429946404B95FE489AF0384120362882D413A50E4E4743CD324D2C7B1CA133E059418AE4BA4EA764EBEA360678362D6262C9EB9EDEE642A5D12A65922C1CC47E2DCC5AEAB081858DFA2A173DDC9C420EB6181887175D7D207D5E10309D7C95FE815270E6ACEE99704EFAC110D9DC3A6727FFDE85F97014ABECBD48600C9A207DE37BA5501BE5A96A8CC745DDB10E00997FAE31D0D2E2515897EDB008B3030C77A89FF56BFD785C4F7234DC52A202DBE598679876AC333E68B9E3B8303DD1A2006A0D657ED2D733E2E14CFDDAF06DEB93C87AA35A3B001FA65374A707A6982D3330186A9C9C357A656EA3038EAB2F94F1E5D5F9F2E214E1F823F02BC76A33ACD5C8E63F53298CD2814DE867656C9675FF5DBC1A69C819A77A35B9D12B47051668804CC9A0F7227F30599D9BA89F9AB55B45DB2C3EBF23D68D54AA9A4E4F1E45215AC5B9024B890B8E6C0D5F46A0387E09F0F6E29BC3F4159FD091F1BF1F41F19D8D93A7C8B3C60AFA29BA83E239CAE8610123F214187F1F1766090C426CB3D3BF8096F57AFBE6E7973DF820DE3A3B52458D0B0DB4EFB2D617DB6ADC067A33089A9B9E15A6DB1D40D086C591DE0795237FE87DFCFA539A08BAF1D9E4616C90FA9E3F21D6935C67BDDC4FC33F08B92D22A9F39BEE04F23C73C26E1A687A81A7CDB15B0C0BE8C4514C9239BE79BFF69945D160FC71F15EA80CEE63BDB84D4FE32CF82A028D69ADD7243E2909C0178FF6415A6D49129998E52C3DB0AE6F808CD85D5FE3A84F85EEAA398DC4E6409B60E96A3C33D6ABC6461D32281CE55ADD4993B08B0A78D903D91B60E9793DA0D8CC62E0F8F71B2D61D774E4E8CE7A9775B0832E1E7EE22B07F8EF6BBA264642CA1BF3EE69620E9AC05BD5CCD3C7945BAB1F02D5C0186F29C9798B693D1C996BCC9C10943F09C73B56A64D2EA819F6F6581C330A1E36D491A9E0BB94E2927815453BFD119857771B3C4F041C5FE3BE484D91C272B8E1EA05F7F62DF5DC83E7F8DC602029BF53990D52A7122E3E34C8367DA120213DF11FEC43212C0C8546ACB11D9F4120B94D5E4C75608BD49CA19D9F4DE5006DFB5C293273925C6A1A15D7371DE5997A95586F0427FE799AF3BA83E944EC5D489B6DA6C399CB06AAACA11B3B5FAFB5415F8762C27582B11A7DEA46F2DFEB4DF071B142D9C47AE0AA031AB721FA03F1952EF87BBE9438A2A95A7F198F4DFF765DBEFE0C01D30759ECE96E1C365A9B7D33C4814D76A35F67ACC6B7BF8E43E3DC9C3B66062B129919FEEB35E63C778A51B10E9319C422C4733359435B6972DB4BA0604F107AC3F782BA29D18002BE2837F26E074A9EED0182909826C726812B7407F3138A22886A13256A2B3041494734A6C96636E1057FAE533E5264B8BCC3749376F9DCA257F26CC70D71538696355545964DD28614410746528220504E8F4BF4D92AEC3C4CFD9A8AA5B29D247A5B2AB2271A082B2E5DD2E8DBDF51A2C64D545661A9BE5B3707CBE507DF57D331B2467843ABE723837F8907224576BF52F6E4F5640AB419D88E1729345635154F9A688AF32EA177A43E6EB5C5B7A51FBAA23939B66F6F854D6416DADED2BBF3D2A7E58A3B52243AC5B2E28844246A08EE2AB47ECC06E4B7DC2F212395411FB623381C6E86D1BBBC7D0107935472BC4377A6A142BED025E37786B545040D940AA14F585C3C6FD475FDCCD1ACC9E9BDE7B60B3C12FCDC7A0EEC1816C1B16B88B1C07C13345FE62C3D704C72AA3CDCA88942CD39DF0842B70D6B6BC3214BDD9A3B40F5D167924DEB43E987C1B1F1438F3952F904E64270A12E0FA2D6C7C468F3DA68FF6110C6913F7492DFC806BB432E11C51A6B5E2D1FC901448A8DA54B3B42F6B60801B936107F9E220962F8F20D04370A2831B3D9B42F7007023F9C87DA8D1C7559D81568977B6E9040F867968DF91EF79FD6367D7E54B7AAEE4199431C29F2DFCF3046FACEC6C39608290CB6D48366CB6AA9BF9CBCF1994A61E8E1403D1105B5B16A3758C51CEE915403DB135623F564E3A32E828E7435110B87ED80EAC43F717F57290D9D1E3C79760A57654F822F80F292D3A2A10D2C11BFB19E4665D8BE2840F231D74A0BCD9B6E667696404F54462A9A1ECFB1FBE4E64A50EB4625C801F9A3B2CDA627B078CAD5C1E527CDFF38C1EFE1106CBA813C4B315D2EC0BE6BDE7E2E12638E8F2BEBD25930EF7916C6E11FFDC5A5F280AD0655EAF6E0656C6D5F899A317891EB8FADDA57C171483D28CFE8BCD4376234080D73EA18056F811C8DBD1F7DD7696E58B1FB68E853F13294A92C73AF9BCD16A502D3CD27EE0DC359DF4CE5F08306D672D86A086E3A1260368A1F56B9CAAF4A244AF296FBF4ADE073B6A42BF5F62C30F0DAC8477D122414623E800EA12BF21E0BCE435EC933211029BE58540140D03A5C35B74970DC66D26C0C340297EF9831D079028DD1D2F442B2ED8A914C11BF55381BA8E91CE80CCC27B4C381B69AD64F70A6F733E5C894C4ECAA8CD4938E76CE35773910C39BC0181232E530E4CB4ECCFAC78D594ECE0A1CBE6795E7BC8815AACF6F5C7EA7493C3ED2B55E11F00A2C47168244A9E36E1DCCF86FCDCF2AA03A452E1869D33B253A7FD4BE5A6302883BCD8DC7E377F4C2C4329F8136C6AD06CB7D4F10BDFBA2BA206D8C8634423B0C7F096AE6BFBE7ED6465846568867C85D74415B834789A1CAF4E7DCFDFE0C065125E0498564B8CC0C12562B6674618FC5EF7613170AE9834931E973BA9F7E27C4AADC93148E43C15684DDAA5DEE36EABDDDC4A457B4A854B4ECCCB71FF873E44F0D1016D767A75232A101F9C691E37378D081E4AD76D0EEC1443AD198447CD07A7873946297F1755ACBA2D33F6331A2E9029C225B0B8995E5DE1845865E97D00FF7AAE873C370995F246372410314062DE2CE3BFB1A87D5A45804B5E9F927638812186D8DD66F94E603EDAD7B318DFF270DB342CF1F8257A4F6A391B4E5144BC5B1E6419EF34AE9C6C0BEE591626548BF077F56CAD8C349E4350F1A006872DC3EF948E344EF3D0A5D537E00B8EC775E6DFA43EC55F162FAF9DF2E24E99C5941A0C1D098DEFF4BBC77FE20BEA4528D6BAD2D7CAB7A5E228D2CAB81E4842896BC0D647BEB1B5698DC804F68A8EA96595E6A3BC90A441EC486FB1B09D4C56C46AEE92CE5A0549CDC32759E850C143EE46CC78A448AD58DC5AA20A9CCEF1559DB940DB2DD436A8FF920AC537B334D9B0AE192ACE93EA3FE242EA47DEF97ED989A8CD9F5425BD62C67B63A5FFDFCFF4E73CDF3F1F7768D1DE13C1428134D0D27B21C5E57045CDD8041B4A86070090957EF9F1A4137B326100577406826AEE74C99FBF53469ABCCC2D7180C643D4660F111D72730675A903FC2A3A4AE61002FF139CE562330C1C9256EE5E4EAFDE3218792DCCE9002409C56ABBFDF6BB4A558903730995CDEB53173C1D5F019C10AEF45D0D23A863F3E0E2BAFF81134EF97558032184C258FB077B67DE07381C959476675F2A5A901B0ADF9F03D975E67FBB15F3CD5EC4DFA921F3C860DBF954362BC89D48C929A070F49F37A9BB79A9E43731052D70507F8266B75981917B734B14DB9C25E3BA22BC9D9D591BD25C1956D190DBE6EB5FB7FBEE27F05EFED485706B92FC1018381A712D27DFAED9B6174D59760B4A18DC3BE58E4E5537E8872D57A9A61D4884704F64CE9443221DD6A6AF6E935B0088C602F26EEABF5860A08BB24DEBFBEF695C07B2690C0736DF6063FFB23DDBAF2A1C03902FFEB7809F6ED5DFEB6F67CC13E3FF0A2A0749FACF2B625788FF9060737DC6CAEAFBF80F476F4D1586591179404972853240FD8E0497F97761B7B08CCA395B968DA08DA3D2BF445F768574A72C61CAEBCFA548EAFE40719587F6D76D7BBCF4417EBBEEF6A73505F9E5C5EE23D41F0D202E68A9E10060A18E61E33457DE179FC21FCE2DA9E7254D8B161789BD6425EC1E4E01A11FCE88B7F83F4594AC9D39A2F84A60723713DF34375A5A62DA4D38757555122E66AC676733BC555306844C31E5ED6BD1990255F5B6E0035B2DF1D7A1F1C330BC7114D52904F4A0CC61E7B9E1E49C409C7FA2781C2141AB3BD21F54E34374BA27CB6ADB2690FA314D93119132EB2175734D8933630C560C24DBE044BDA5BBADCD3C4F82C72F88282D4D74A2F078574E199AF6CB52B622475E7E637D70B650FC2557930F10C369CEAFF9EDC2E155FEDBC9A0F5B610ECD1985D973BC9900D0BF9D64E7FBF8644D952F474822F8F533E28FC349D2B36EF542025A9D8C0ADC2A4596E2BFD629448BB24A0E2913F174D2CF5419764BA6E58DEE0BBC1CEE9697875AE6D759F096E082EE388"
		LocalStatePath:=EnvGet2("Local AppData") "\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"

		If DirExist(LocalStatePath) {
			bin:=Hex2Bin(StartBin)		
			If FileExist(LocalStatePath "\start.bin") {
				FileDelete LocalStatePath "\start.bin"
				FileAppend bin, LocalStatePath "\start.bin","cp0"
			} Else {
				FileDelete LocalStatePath "\start2.bin"
				FileAppend bin, LocalStatePath "\start2.bin","cp0"
			}	
			PID:=ProcessClose("StartMenuExperienceHost.exe")
			If !ProcessWaitClose(PID , 5000)
				TrayTip GetLangText("Text_ClearStartMenu_Done"), App.Name
		} Else
			MsgBox "Not supported Windows " A_OSVersion, App.Name, "Iconx"
	} Else If VerCompare(A_OSVersion,"10.0.16299")>=0 {
		Loop Reg, HKCU "\SOFTWARE\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount", "K" {
			If InStr(A_LoopRegName, "$start.suggestions$windows.data.curatedtilecollection.tilecollection")
				RegWrite '020000005ecce65175f1d80100000000434201000a0a00ca32000000', "REG_BINARY", HKCU "\SOFTWARE\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount\" A_LoopRegName "\Current", "Data"
			Else If InStr(A_LoopRegName, "$start.tilegrid$windows.data.curatedtilecollection.tilecollection")
				RegWrite '020000006bc38df82ff8d80100000000434201000a0a00d0140cca3200e22c01010000', "REG_BINARY", HKCU "\SOFTWARE\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount\" A_LoopRegName "\Current", "Data"
		}
		ProcessClose "explorer.exe"
	} Else
		MsgBox "Not supported Windows " A_OSVersion, App.Name, "Iconx"
}

BtnRestartExplorer_Click(*) {
	ProcessClose "explorer.exe"
}
