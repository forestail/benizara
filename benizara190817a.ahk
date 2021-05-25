﻿;-----------------------------------------------------------------------
;	名称：benizara / 紅皿
;	機能：Yet another NICOLA Emulaton Software
;         キーボード配列エミュレーションソフト
;	ver.0.1.4.7 .... 2021/05/17
;	作者：Ken'ichiro Ayaki
;-----------------------------------------------------------------------
	#InstallKeybdHook
	#MaxhotkeysPerInterval 400
	#MaxThreads 64
	#KeyHistory
#SingleInstance, Off
	SetStoreCapsLockMode,On
	g_Ver := "ver.0.1.4.7"
	g_Date := "2021/5/22"
	MutexName := "benizara"
    If DllCall("OpenMutex", Int, 0x100000, Int, 0, Str, MutexName)
    {
		Traytip,キーボード配列エミュレーションソフト「紅皿」,多重起動は禁止されています。
        ExitApp
	}
    hMutex := DllCall("CreateMutex", Int, 0, Int, False, Str, MutexName)
	
	SetWorkingDir, %A_ScriptDir%

	idxLogs := 0
	aLogCnt := 0
	loop, 64
	{
		_idx := A_Index - 1
		aLog%_idx% := "_"
	}
	full_command_line := DllCall("GetCommandLine", "str") 
	if(RegExMatch(full_command_line, " /create(?!\S)")) 
	{
		thisCmd = schtasks.exe /create /tn benizara /tr `"%A_ScriptFullPath%`" /sc onlogon /rl highest /F
		DllCall("ReleaseMutex", Ptr, hMutex)
		Run *Runas %thisCmd%
		ExitApp 
	}
	if(RegExMatch(full_command_line, " /delete(?!\S)")) 
	{
		thisCmd := "schtasks.exe /delete /tn \benizara /F"
		DllCall("ReleaseMutex", Ptr, hMutex)
		Run *Runas %thisCmd%
		ExitApp
	}
	if(RegExMatch(full_command_line, " /admin(?!\S)")) 
	{
		DllCall("ReleaseMutex", Ptr, hMutex)
		Run *Runas %A_ScriptFullPath%
		ExitApp
	}
	g_Romaji := "A"
	g_Oya    := "N"
	g_Koyubi := "N"
	g_Modifier := 0
	g_LayoutFile := ".\NICOLA配列.bnz"
	g_Continue := 1
	g_Threshold := 150	; 
	g_MaxTimeout := 400
	g_ThresholdSS := 80	; 
	g_OverlapMO := 50
	g_OverlapOM := 50
	g_OverlapSS := 70
	g_ZeroDelay := 1		; 零遅延モード
	g_ZeroDelayOut := ""
	g_ZeroDelaySurface := ""	; 零遅延モードで出力される表層文字列
	g_Offset := 20
	g_trigger := ""
	
	INFINITE := +2147483648

	g_OyaKeyOn  := Object()
	g_OyaTick   := Object()
	g_OyaUpTick := Object()
	g_Interval  := Object()
	g_LastKey   := Object()		; 最後に入力したキーを濁音や半濁音に置き換える
	g_LastKey["表層"] := ""
	g_LastKey["状態"] := ""

	g_OyaAlt := Object()	; 反対側の親指キー
	g_OyaAlt["R"] := "L"
	g_OyaAlt["L"] := "R"

	g_metaKeyUp := Object()		; 親指キーを離す
	g_metaKeyUp["R"] := "r"
	g_metaKeyUp["L"] := "l"
	g_metaKeyUp["M"] := "m"
	g_metaKeyUp["S"] := "s"
	g_metaKeyUp["X"] := "x"
	g_metaKeyUp["1"] := "_1"
	g_metaKeyUp["2"] := "_2"

	g_MojiCount := Object()	; 親指キーシフトの文字押下カウンター
	g_MojiCount["R"] := 0
	g_MojiCount["L"] := 0

	g_RomajiOnHold := Object()
	g_KoyubiOnHold := Object()
	g_OyaOnHold := Object()
	g_MojiOnHold := Object()
	g_MojiTick := Object()
	g_MojiUpTick := Object()
	
	g_sansTick := INFINITE
	g_sans := "N"
	
	g_debugout := ""
	
	g_Pause := 0
	g_KeyPause := "Pause"
	vLayoutFile := g_LayoutFile
	g_Tau := 400
	GoSub,Init
	Gosub,ReadLayout
	Traytip,キーボード配列エミュレーションソフト「紅皿」,benizara %g_Ver% `n%g_layoutName%　%g_layoutVersion%
	g_allTheLayout := vAllTheLayout
	g_LayoutFile := vLayoutFile
	kup_save := Object()

	g_SendTick := INFINITE
	if(A_IsCompiled == 1)
	{
		Menu, Tray, NoStandard
	}
	Menu, Tray, Add, 紅皿設定,Settings
	;Menu, Tray, Add, 配列,ShowLayout
	Menu, Tray, Add, ログ,Logs
	Menu, Tray, Add, 一時停止,DoPause
	Menu, Tray, Add, 再開,DoResume
	Menu, Tray, Add, 終了,MenuExit
	Gosub,DoResume
	;Menu, Tray,disable,再開
	;if(Path_FileExists(A_ScriptDir . "\benizara_on.ico")==1)
	;{
	;	Menu, Tray, Icon, %A_ScriptDir%\benizara_on.ico , ,1
	;}
	SetBatchLines, -1
	SetHookInit()
	fPf := Pf_Init()
	_currentTick := Pf_Count()	;A_TickCount
	g_MojiTick[0] := _currentTick
	g_OyaTick["R"] := _currentTick
	g_OyaTick["L"] := _currentTick
	VarSetCapacity(lpKeyState,256,0)
	SetTimer,Interrupt10,10
	
	vIntKeyUp := 0
	vIntKeyDn := 0

	SetHook("off","off")

	g_hookShift := "off"
	SetHookShift("off")
	return


MenuExit:
	SetTimer,Interrupt10,off
	DllCall("ReleaseMutex", Ptr, hMutex)
	exitapp

;-----------------------------------------------------------------------
;	一時停止(Pause)
;-----------------------------------------------------------------------
DoPause:
	Menu, Tray,disable,一時停止
	Menu, Tray,enable,再開
	g_Pause := 1
	if(Path_FileExists(A_ScriptDir . "\benizara_off.ico")==1)
	{
		Menu, Tray, Icon, %A_ScriptDir%\benizara_off.ico , ,1
	}
	return

;-----------------------------------------------------------------------
;	再開（一時停止の解除）
;-----------------------------------------------------------------------
DoResume:
	Menu, Tray,enable,一時停止
	Menu, Tray,disable,再開
	g_Pause := 0
	if(Path_FileExists(A_ScriptDir . "\benizara_on.ico")==1)
	{
		Menu, Tray, Icon, %A_ScriptDir%\benizara_on.ico , ,1
	}
	return	


#include IME.ahk
#include ReadLayout6.ahk
#include Settings7.ahk
#include PfCount.ahk
#include Logs1.ahk
#include Path.ahk

;-----------------------------------------------------------------------
; 親指シフトキー
; スペースキーに割り当てられていれば連続打鍵
;-----------------------------------------------------------------------

keydownR:
keydownL:
	Critical
	GuiControl,2:,vkeyDN%g_layoutPos%,□
	g_trigger := g_metaKey

	gosub,Polling
	RegLogs(g_metaKey . " down")
	g_OyaTick[g_metaKey] := Pf_Count()				; A_TickCount
	if(keyState[g_layoutPos] != 0 && (g_KeyRepeat = 1 || kName = "sc039"))
	{
	 	; キーリピートの処理
		g_Oya := g_metaKey
		g_OyaKeyOn[g_Oya] := kName
		g_Interval["M" . g_Oya] := g_OyaTick[g_Oya] - g_MojiTick[0]	; 文字キー押しから当該親指キー押しまでの期間

		keyState[g_layoutPos] := g_OyaTick[g_Oya]
		
		Gosub, SendOnHoldO	; 保留キーの打鍵
		; 連続モードでなければ押されていない状態に
		if(g_Continue == 1)
		{
			g_OyaOnHold[0] := g_Oya
			g_SendTick := INFINITE	;g_OyaTick[g_Oya] + minimum(floor((g_Threshold*(100-g_OverlapOM))/g_OverlapOM),g_MaxTimeout)
			g_KeyInPtn := g_Oya
		}
		critical,off
		return
	}
	if(keyState[g_layoutPos] == 0) 	; キーリピートの抑止
	{
		g_MojiCount[g_metaKey] := 0
		g_Oya := g_metaKey
		g_Interval["M" . g_Oya] := g_OyaTick[g_Oya] - g_MojiTick[0]	; 文字キー押しから当該親指キー押しまでの期間

		keyState[g_layoutPos] := g_OyaTick[g_Oya]
		if(g_KeyInPtn == "MM" || g_KeyInPtn == "MMm")	; M1M2オン状態 M1M2オンM1オフ状態
		{
			; ３キー判定
			g_Interval["M" . g_metaKey] := g_OyaTick[g_metaKey] - g_MojiTick[0]
			g_Interval["S12"]  := g_MojiTick[0] - g_MojiTick[1]	; 前回の文字キー押しからの期間
			if(g_Interval["S12"] < g_Interval["M" . g_metaKey]) {
				_mode := g_RomajiOnHold[0] . g_OyaOnHold[0] . g_KoyubiOnHold[0]
				if(ksc[_mode . g_MojiOnHold[0]]<=1 || (ksc[_mode . g_MojiOnHold[0]]<=2 && kdn[_mode . g_MojiOnHold[1] . g_MojiOnHold[0]]=="")) {
					Gosub, SendOnHoldM2
					Gosub, SendOnHoldM
				} else {
					Gosub, SendOnHoldMM
				}
			} else {
				Gosub, SendOnHoldM2		; 保留した２文字前だけを打鍵してMオン状態に遷移
			}
		}
		else if(g_KeyInPtn == "MMM")	; M1M2M3オン状態
		{
			Gosub, SendOnHoldMMM
		}
		
		if(g_KeyInPtn == "") 		;S1)初期状態
		{
			g_OyaKeyOn[g_Oya] := kName
			g_OyaOnHold[0] := g_Oya
			g_SendTick := g_OyaTick[g_Oya] + minimum(floor((g_Threshold*(100-g_OverlapOM))/g_OverlapOM),g_MaxTimeout)
			g_KeyInPtn := g_KeyInPtn . g_Oya	;S3に遷移
		}
		else if(g_KeyInPtn == "M")	;S2)Mオン状態
		{
			g_Interval["M" . g_metaKey] := g_OyaTick[g_metaKey] - g_MojiTick[0]
			if(g_Interval["M" . g_metaKey] > minimum(floor((g_Threshold*(100-g_OverlapMO))/g_OverlapMO),g_MaxTimeout)) {
				Gosub, SendOnHoldM	; タイムアウト・保留キーの打鍵
			}
			g_OyaKeyOn[g_Oya] := kName
			g_OyaOnHold[0] := g_Oya
			g_SendTick := g_OyaTick[g_Oya] + minimum(floor((g_Threshold*(100-g_OverlapOM))/g_OverlapOM),g_MaxTimeout)
			g_KeyInPtn := g_KeyInPtn . g_Oya	;OオンまたはM-Oオンに遷移
		} 
		else if(g_KeyInPtn == g_OyaAlt[g_Oya])	;S3)Oオン状態　（既に他の親指キーオン）
		{
			Gosub, SendOnHoldO	; 他の親指キー（保留キー）の打鍵

			g_OyaKeyOn[g_Oya] := kName
			g_OyaOnHold[0] := g_Oya
			g_SendTick := g_OyaTick[g_Oya] + minimum(floor((g_Threshold*(100-g_OverlapOM))/g_OverlapOM),g_MaxTimeout)
			g_KeyInPtn := g_Oya				;S4)Oオンに遷移
		}
		else if(g_KeyInPtn == "M" . g_OyaAlt[g_Oya])	;S4)M-Oオン状態で反対側のOキーオン
		{
			Gosub, SendOnHoldMO	; 保留キーの打鍵
			g_OyaKeyOn[g_Oya] := kName			
			g_OyaOnHold[0] := g_Oya
			g_SendTick := g_OyaTick[g_Oya] + minimum(floor((g_Threshold*(100-g_OverlapOM))/g_OverlapOM),g_MaxTimeout)
			g_KeyInPtn := g_KeyInPtn . g_Oya	; S4)M-Oオンに遷移
		}
		else if(g_KeyInPtn == g_OyaAlt[g_Oya] . "M")	;S5)O-Mオン状態で反対側のOキーオン
		{
			; 処理B 3キー判定
			g_Interval[g_OyaAlt[g_Oya] . "M"] := g_MojiTick[0] - g_OyaTick[g_OyaAlt[g_Oya]]	; 他の親指キー押しから文字キー押しまでの期間
			if(g_Interval["M" . g_Oya] > g_Interval[g_OyaAlt[g_Oya] . "M"])
			{
				Gosub, SendOnHoldMO	; 保留キーの打鍵　Mモードに
				g_OyaKeyOn[g_Oya] := kName
				g_OyaOnHold[0] := g_Oya
				g_SendTick := g_OyaTick[g_Oya] + minimum(floor((g_Threshold*(100-g_OverlapOM))/g_OverlapOM),g_MaxTimeout)
				g_KeyInPtn := g_KeyInPtn . g_Oya	; S4)M-Oオンに遷移
			}
			else
			{
				if(g_ZeroDelayOut<>"")
				{
					CancelZeroDelayOut(g_ZeroDelay)
				}
				Gosub, SendOnHoldO	; 保留キーの打鍵

				g_OyaKeyOn[g_Oya] := kName
				g_OyaOnHold[0] := g_Oya
				g_SendTick := g_OyaTick[g_Oya] + minimum(floor((g_Interval["M" . g_Oya]*g_OverlapMO)/(100-g_OverlapMO)),g_MaxTimeout)
				g_KeyInPtn := g_KeyInPtn . g_Oya	; S4)M-Oオンに遷移
				SendZeroDelay(g_RomajiOnHold[0] . g_OyaOnHold[0] . g_KoyubiOnHold[0], g_MojiOnHold[0], g_ZeroDelay)
			}
		}
		else if(g_KeyInPtn="RMr" || g_KeyInPtn="LMl")	; S6)O-M-Oオフ状態
		{
			Gosub, SendOnHoldMO	; 保留キーの打鍵
			g_OyaKeyOn[g_Oya] := kName
			g_OyaOnHold[0] := g_Oya
			g_SendTick := g_OyaTick[g_Oya] + minimum(floor((g_Threshold*(100-g_OverlapOM))/g_OverlapOM),g_MaxTimeout)
			g_KeyInPtn := g_KeyInPtn . g_Oya		; S3)Oオンに遷移
		}
	}
	if(g_KeyInPtn == "L" || g_KeyInPtn == "R") {
		g_SendTick := INFINITE
	}
	critical,off
	return  

keyupR:
keyupL:
	Critical
	GuiControl,2:,vkeyDN%g_layoutPos%,　
	g_trigger := g_metaKeyUp[g_metaKey]

	gosub,Polling
	g_OyaUpTick[g_metaKey] := Pf_Count()				;A_TickCount
	if(keyState[g_layoutPos] != 0)	; 右親指シフトキーの単独シフト
	{
		RegLogs(g_metaKey . " up")
		
		if(g_Oya == g_metaKey) {
			g_Interval["M_" . g_Oya] := g_OyaUpTick[g_Oya] - g_MojiTick[0]	; 文字キー押しから右親指キー解除までの期間
			g_Interval[g_Oya . "_" . g_Oya] := g_OyaUpTick[g_Oya] - g_OyaTick[g_Oya]	; 右親指キー押しから右親指キー解除までの期間

			if(g_KeyInPtn = g_Oya)		;S3)Oオン状態
			{
				Gosub, SendOnHoldO	;保留親指キーの打鍵
			}
			else if(g_KeyInPtn = "M" . g_Oya)	;S4)M-Oオン状態
			{
				Gosub, SendOnHoldMO	; 保留キーの同時打鍵
			}
			else if(g_KeyInPtn = g_Oya . "M")	;S5)O-Mオン状態
			{
				if(g_Interval["M_" . g_Oya] > g_Threshold || g_MojiCount[g_Oya] == 1)
				{
					; タイムアウト状態または親指シフト１文字目：親指シフト文字の出力
					Gosub, SendOnHoldMO	; 保留キーの打鍵
				} else {
					; 処理D
					vOverlap := floor((100*g_Interval["M_" . g_Oya])/g_Interval[g_Oya . "_" . g_Oya])
					if(vOverlap < g_OverlapOM && g_Interval["M_" . g_Oya] <= g_Tau)
					{
						;Gosub, SendOnHoldO	; 保留キーの単独打鍵
						g_SendTick := g_OyaUpTick[g_Oya] + g_Interval["M_" . g_Oya]
						g_KeyInPtn := g_KeyInPtn . g_metaKeyUp[g_Oya]	;"RMr" "OMo" "LMl"
					} else {
						Gosub, SendOnHoldMO	; 保留キーの打鍵
					}
				}
			}
			;else if(g_KeyInPtn="M" || g_KeyInPtn="RMr" || g_KeyInPtn="LMl") ; S2)Mオン状態 S6)O-M-Oオフ状態
			;{
				; 何もしない
			;}
		}
		g_OyaKeyOn[g_metaKey] := ""
	}
	keyState[g_layoutPos] := 0
	
	if(g_Oya == g_metaKey) {
		if(g_Continue == 1) {
			; 反対側の親指キーが押されていなければ N に設定
			g_Oya := g_OyaAlt[g_Oya]
			_layout := g_Oya2Layout[g_Oya]
			_keyName := keyNameHash[_layout]
			_keyState := GetKeyState(_keyName,"P")
			if(_keyState == 0) {
				g_Oya := "N"
			}
		} else {
			g_Oya := "N"
		}
	}
	g_MojiCount[g_metaKey] := 0
	critical,off
	return
;----------------------------------------------------------------------
; 最小値
;----------------------------------------------------------------------
minimum(val0, val1) {
	if(val0 > val1)
	{
		return val1
	}
	else
	{
		return val0
	}
}
;----------------------------------------------------------------------
; 最大値
;----------------------------------------------------------------------
maximum(val0, val1) {
	if(val0 < val1)
	{
		return val1
	}
	else
	{
		return val0
	}
}
;----------------------------------------------------------------------
; 零遅延モード出力のキャンセル
;----------------------------------------------------------------------
CancelZeroDelayOut(g_ZeroDelay) {
	global g_ZeroDelaySurface, g_ZeroDelayOut
	if(g_ZeroDelay == 1) {
		_len := StrLen(g_ZeroDelaySurface)
		loop, %_len%
		{
			SubSend(MnDown("BS") . MnUp("BS"))
		}
	}
	g_ZeroDelaySurface := ""
	g_ZeroDelayOut := ""
}

;----------------------------------------------------------------------
; キーダウン時にSendする文字列を設定する
; 引数　：aStr：対応するキー入力
; 戻り値：Sendの引数
;----------------------------------------------------------------------
MnDown(aStr) {
	vOut := ""
	if(aStr<>"")
	{
		vOut = {Blind}{%aStr% down}
	}
	return vOut
}
;----------------------------------------------------------------------
; キーアップ時にSendする文字列を設定する
; 引数　：aStr：対応するキー入力
; 戻り値：Sendの引数
;----------------------------------------------------------------------
MnUp(aStr) {
	vOut := ""
	if(aStr<>"")
	{
		vOut = {Blind}{%aStr% up}
	}
	return vOut
}
;--------------------------------------------------------------------y-
; 送信文字列の出力
;----------------------------------------------------------------------
SubSend(vOut)
{
	global aLog,idxLogs, aLogCnt, g_KeyInPtn, g_trigger
	
	if(vOut<>"")
	{
		SetKeyDelay, -1
		Send, %vOut%
		RegLogs("       " . substr(g_KeyInPtn . "    ",1,4) . substr(g_trigger . "    ",1,4) . vOut)
	}
	return
}
;--------------------------------------------------------------------y-
; キーから送信文字列に変換
;----------------------------------------------------------------------
MnDownUp(key)
{
	if(key <> "")
		return "{Blind}{" . key . " down}{" . key . " up}"
	else
		return ""
}
;--------------------------------------------------------------------y-
; ログ保存
;----------------------------------------------------------------------
RegLogs(thisLog)
{
	global aLog, idxLogs, aLogCnt
	static tickLast
	
	tickCount := Pf_Count()	;A_TickCount

	;SetFormat Integer,D
	_timeSinceLastLog := tickCount - tickLast
	_tmp := SubStr("      ",1,6-StrLen(_timeSinceLastLog)) . _timeSinceLastLog
	aLog%idxLogs% := _tmp . " " . thisLog
	idxLogs := idxLogs + 1
	idxLogs := idxLogs & 63
	if(aLogCnt < 64)
	{
		aLogCnt := aLogCnt + 1
	} else {
		aLogCnt := 64
	}
	tickLast := tickCount
}

;----------------------------------------------------------------------
; 保留キーの出力：セットされた文字のセットされた親指の出力
;----------------------------------------------------------------------
SendOnHoldMO:
	_mode := g_RomajiOnHold[0] . g_OyaOnHold[0] . g_KoyubiOnHold[0]
	SendOnHold(_mode, g_MojiOnHold[0], g_ZeroDelay)

	g_RomajiOnHold[0] := ""
	g_OyaOnHold[0]    := ""
	g_KoyubiOnHold[0] := ""
	g_MojiOnHold[0]   := ""
	
	g_SendTick := INFINITE
	g_KeyInPtn := ""
	g_OyaKeyOn[g_Oya] := ""
	if(g_Continue == 0) {
		g_Oya := "N"
	}
	return

;----------------------------------------------------------------------
; 保留キーの出力関数：
; _mode : モードまたは文字同時打鍵の第１文字
; _MojiOnHold : 現在の打鍵文字の場所 A01-E14
;----------------------------------------------------------------------
SendOnHold(_mode, _MojiOnHold, g_ZeroDelay)
{
	global kdn, kup, kup_save, g_ZeroDelayOut, g_ZeroDelaySurface, kLabel, kst
	global g_LastKey, g_Koyubi
	
	vOut                  := kdn[_mode . _MojiOnHold]
	kup_save[_MojiOnHold] := kup[_mode . _MojiOnHold]
	_kLabel := kLabel[_mode . _MojiOnHold]
	_kst    := kst[_mode . _MojiOnHold]
	
	_nextKey := nextDakuten(_mode,_MojiOnHold)
	if(_nextKey != "") {
		g_LastKey["表層"] := _nextKey
		_aStr := "後" . kana2Romaji(g_LastKey["表層"])
		GenSendStr3(_aStr, _down, _up)
		vOut                   := _down
		kup_save[_MojiOnHold]  := _up
		_kLabel := g_LastKey["表層"]
		_kst    := g_LastKey["状態"]
	} else {
		g_LastKey["表層"] := kLabel[_mode . _MojiOnHold]
		g_LastKey["状態"] := kst[_mode . _MojiOnHold]
	}
	if(g_Koyubi=="K" && _kst == "M") {
		vOut := "{capslock}" . vOut . "{capslock}"
	}
	if(g_ZeroDelay = 1)
	{
		if(vOut <> g_ZeroDelayOut)
		{
			CancelZeroDelayOut(g_ZeroDelay)
			SubSend(vOut)
		}
		g_ZeroDelayOut := ""
		g_ZeroDelaySurface := ""
	} else {
		SubSend(vOut)
	}
}
;----------------------------------------------------------------------
; 保留キーの出力：セットされた文字の出力
;----------------------------------------------------------------------
SendOnHoldM:
	_mode := g_RomajiOnHold[0] . "N" . g_KoyubiOnHold[0]
	SendOnHold(_mode, g_MojiOnHold[0], g_ZeroDelay)

	g_RomajiOnHold[0] := ""
	g_OyaOnHold[0]    := ""
	g_KoyubiOnHold[0] := ""
	g_MojiOnHold[0]   := ""
	
	g_SendTick := INFINITE
	if(g_KeyInPtn = "MR")
	{
		g_keyInPtn := "R"
	}
	else if(g_KeyInPtn = "ML")
	{
		g_keyInPtn := "L"
	}
	else if(g_KeyInPtn = "M")
	{
		g_keyInPtn := ""
	}
	else if(g_KeyInPtn = "RMr" || g_KeyInPtn = "LMl")
	{
		g_keyInPtn := ""
	}
	else if(g_KeyInPtn = "MM" || g_KeyInPtn = "MMm")
	{
		g_keyInPtn := "M"
	}	
	return

;----------------------------------------------------------------------
; 保留キーの出力：セットされた文字の出力
;----------------------------------------------------------------------
SendOnHoldMM:
	if(g_MojiOnHold[0] == "") 
	{
		return
	}
	_mode := g_RomajiOnHold[0] . g_OyaOnHold[0] . g_KoyubiOnHold[0]
	if(kdn[_mode . g_MojiOnHold[1] . g_MojiOnHold[0]] != "") {
		SendOnHold(_mode, g_MojiOnHold[1] . g_MojiOnHold[0], g_ZeroDelay)
		g_RomajiOnHold[1] := ""
		g_RomajiOnHold[0] := ""
		g_OyaOnHold[1]    := ""
		g_OyaOnHold[0]    := ""
		g_KoyubiOnHold[1] := ""
		g_KoyubiOnHold[0] := ""
		
		g_MojiOnHold[1]   := ""
		g_MojiOnHold[0]   := ""
	
		g_SendTick := INFINITE
		g_keyInPtn := ""
	} else {
		Gosub, SendOnHoldM2
		Gosub, SendOnHoldM
	}
	return
	
;----------------------------------------------------------------------
; 保留キーの出力：セットされた文字の出力
;----------------------------------------------------------------------
SendOnHoldMMM:
	if(g_MojiOnHold[0] == "") 
	{
		return
	}
	_mode := g_RomajiOnHold[0] . g_OyaOnHold[0] . g_KoyubiOnHold[0]
	if(kdn[_mode . g_MojiOnHold[2] . g_MojiOnHold[1] . g_MojiOnHold[0]] != "") {
		SendOnHold(_mode, g_MojiOnHold[2] . g_MojiOnHold[1] . g_MojiOnHold[0], g_ZeroDelay)	
		g_RomajiOnHold[2] := ""
		g_RomajiOnHold[1] := ""
		g_RomajiOnHold[0] := ""
		g_OyaOnHold[2]    := ""
		g_OyaOnHold[1]    := ""
		g_OyaOnHold[0]    := ""
		g_KoyubiOnHold[2] := ""
		g_KoyubiOnHold[1] := ""
		g_KoyubiOnHold[0] := ""
		
		g_MojiOnHold[2]   := ""
		g_MojiOnHold[1]   := ""
		g_MojiOnHold[0]   := ""
	
		g_SendTick := INFINITE
		g_keyInPtn := ""
	} else if(kdn[_mode . g_MojiOnHold[2] . g_MojiOnHold[1]] != "") {
		SendOnHold(_mode, g_MojiOnHold[2] . g_MojiOnHold[1], g_ZeroDelay)
		g_RomajiOnHold[2] := ""
		g_RomajiOnHold[1] := ""
		g_OyaOnHold[2]    := ""
		g_OyaOnHold[1]    := ""
		g_KoyubiOnHold[2] := ""
		g_KoyubiOnHold[1] := ""
		
		g_MojiOnHold[2]   := ""
		g_MojiOnHold[1]   := ""
		Gosub,SendOnHoldM
	} else {
		SendOnHold(_mode, g_MojiOnHold[2], g_ZeroDelay)
		g_RomajiOnHold[2] := ""
		g_OyaOnHold[2]    := ""
		g_KoyubiOnHold[2] := ""
		g_MojiOnHold[2]   := ""
		Gosub,SendOnHoldMM
	}
	return
;----------------------------------------------------------------------
; 保留キーの出力：セットされた２文字前の出力
;----------------------------------------------------------------------
SendOnHoldM2:
	if(g_MojiOnHold[1] == "") 
	{
		return
	}
	_mode := g_RomajiOnHold[1] . g_OyaOnHold[1] . g_KoyubiOnHold[1]
	SendOnHold(_mode, g_MojiOnHold[1], g_ZeroDelay)
	SubSend(kup_save[g_MojiOnHold[1]])

	g_RomajiOnHold[1] := ""
	g_OyaOnHold[1]    := ""
	g_KoyubiOnHold[1] := ""
	g_MojiOnHold[1]   := ""
	g_keyInPtn := "M"
	return

;----------------------------------------------------------------------
; 保留された親指キーの出力
; 2020/10/16 : スペースキーをホールドしているときは単独打鍵する
;----------------------------------------------------------------------
SendOnHoldO:
	if(g_KeyInPtn=="RM" || g_KeyInPtn=="RMr" || g_KeyInPtn=="MR" || g_KeyInPtn=="R")
	{
		if(g_OyaKeyOn["R"]!="")
		{
			if(g_KeySingle == "有効" || g_OyaKeyOn["R"] == "sc039")
			{
				SubSend(MnDown(g_OyaKeyOn["R"]) . MnUp(g_OyaKeyOn["R"]))
			}
			g_OyaKeyOn["R"] := 0
		}
		if(g_KeyInPtn=="RM" || g_KeyInPtn=="RMr" || g_KeyInPtn=="MR")
		{
			g_keyInPtn := "M"
		}
		else if(g_KeyInPtn=="R")
		{
			g_keyInPtn := ""
		}
	}
	else if(g_KeyInPtn=="LM" || g_KeyInPtn=="LMl" || g_KeyInPtn=="ML" || g_KeyInPtn=="L")
	{
		if(g_OyaKeyOn["L"]!="")
		{
			if(g_KeySingle == "有効" || g_OyaKeyOn["L"] == "sc039")
			{
				SubSend(MnDown(g_OyaKeyOn["L"]) . MnUp(g_OyaKeyOn["L"]))
			}
			g_OyaKeyOn["L"] := ""
		}
		if(g_KeyInPtn=="LM" || g_KeyInPtn=="LMl" || g_KeyInPtn=="ML")
		{
			g_keyInPtn := "M"
		}
		else if(g_KeyInPtn=="L")
		{
			g_keyInPtn := ""
		}
	}
	if(g_Continue == 0) {
		g_Oya := "N"
	}
	return

;----------------------------------------------------------------------
; 文字キー押下
;----------------------------------------------------------------------
keydownM:
	Critical
	GuiControl,2:,vkeyDN%g_layoutPos%,□
	g_trigger := g_metaKey
	
	RegLogs(kName . " down")
	gosub,Polling
	keyState[g_layoutPos] := Pf_Count()
	g_MojiTick[1] := g_MojiTick[0]
	g_MojiTick[0] := keyState[g_layoutPos]
	g_sansTick := INFINITE
	if(ShiftMode[g_Romaji] == "プレフィックスシフト") {
		Gosub,ScanModifier
		if(g_Modifier != 0)		; 修飾キーが押されている
		{
			; 修飾キー＋文字キーの同時押しのときは、英数レイアウトで出力
			SendAN("AN" . KoyubiOrSans(g_Koyubi,g_sans), g_layoutPos)

			g_MojiOnHold[0]   := ""

			g_RomajiOnHold[0] := ""
			g_OyaOnHold[0]    := ""
			g_KoyubiOnHold[0] := ""
			g_SendTick := INFINTE
			g_KeyInPtn := ""

			g_prefixshift := ""
			critical,off
			return
		}
		if(g_prefixshift <> "" )
		{
			g_MojiOnHold[0]   := g_layoutPos
			g_RomajiOnHold[0] := g_Romaji
			g_KoyubiOnHold[0] := KoyubiOrSans(g_Koyubi,g_sans)
			g_OyaOnHold[0]    := g_prefixshift
			SendKey(g_RomajiOnHold[0] . g_OyaOnHold[0] . g_KoyubiOnHold[0], g_MojiOnHold[0])
			
			g_prefixshift := ""
			critical,off
			return
		}
		g_MojiOnHold[0]   := g_layoutPos
		g_RomajiOnHold[0] := g_Romaji
		g_OyaOnHold[0]    := "N"
		g_KoyubiOnHold[0] := KoyubiOrSans(g_Koyubi,g_sans)
		SendKey(g_RomajiOnHold[0] . g_OyaOnHold[0] . g_KoyubiOnHold[0], g_MojiOnHold[0])
		critical,off
		return
	}
	if(ShiftMode[g_Romaji] == "小指シフト") {
		Gosub,ScanModifier
		if(g_Modifier != 0)		; 修飾キーが押されている
		{
			; 修飾キー＋文字キーの同時押しのときは、英数レイアウトで出力
			SendAN("AN" . KoyubiOrSans(g_Koyubi,g_sans), g_layoutPos)
			
			g_MojiOnHold[0]   := ""
			
			g_RomajiOnHold[0] := ""
			g_OyaOnHold[0]    := ""
			g_KoyubiOnHold[0] := ""
			g_SendTick := INFINITE
			g_KeyInPtn := ""

			g_prefixshift := ""
			critical,off
			return
		}
		g_MojiOnHold[0]   := g_layoutPos
		g_RomajiOnHold[0] := g_Romaji
		g_OyaOnHold[0]    := "N"
		g_KoyubiOnHold[0] := KoyubiOrSans(g_Koyubi,g_sans)
		SendKey(g_RomajiOnHold[0] . g_OyaOnHold[0] . g_KoyubiOnHold[0], g_MojiOnHold[0])
		critical,off
		return
	}
	
	; 親指シフトまたは文字同時打鍵の文字キーダウン
	if(g_KeyInPtn = "M")	; S2)Mオン状態
	{
		g_Interval["S12"] := g_MojiTick[0] - g_MojiTick[1]	; 前回の文字キー押しからの期間
		_mode := g_RomajiOnHold[0] . g_OyaOnHold[0] . g_KoyubiOnHold[0]
		if(ksc[_mode . g_layoutPos]<=1 || (ksc[_mode . g_layoutPos]==2 && kdn[_mode . g_MojiOnHold[0] . g_layoutPos]=="")) {
			; 保留中の１文字を確定（出力）
			Gosub, SendOnHoldM
		}
	}
	else if(g_KeyInPtn == "MM") {
		; M3 のキー入力
		_mode := g_RomajiOnHold[0] . g_OyaOnHold[0] . g_KoyubiOnHold[0]
		if(ksc[_mode . g_layoutPos]<=2 || (ksc[_mode . g_layoutPos]==3 && kdn[_mode . g_MojiOnHold[0] . g_MojiOnHold[1] . g_layoutPos] == "")) {
			g_Interval["S23"] := g_Interval["S12"]
			g_Interval["S12"] := g_MojiTick[0] - g_MojiTick[1]	; 前回の文字キー押しからの期間　３キー判定
			if(kdn[_mode . g_MojiOnHold[1] . g_MojiOnHold[0]]=="" || g_Interval["S12"] < g_Interval["S23"]) {
				Gosub, SendOnHoldM2		; 保留した２文字前だけを打鍵してMオン状態に遷移
			} else {
				; 保留中の同時打鍵を確定
				Gosub, SendOnHoldMM		; ２文字を同時打鍵として出力して初期状態に
			}
		}
	}
	else if(g_KeyInPtn == "MMm") {
		g_Interval["S_13"] := g_MojiTick[0] - g_MojiUpTick[0]	; 前回の文字キーオフからの期間
		_mode := g_RomajiOnHold[0] . g_OyaOnHold[0] . g_KoyubiOnHold[0]
		if(kdn[_mode . g_MojiOnHold[1] . g_MojiOnHold[0]] != "") {
			; 同時打鍵を確定
			Gosub, SendOnHoldMM		;２文字を同時打鍵として出力して初期状態に
		} else {
			Gosub, SendOnHoldM2		; 保留した２文字前だけを打鍵してMオン状態に遷移
		}
	}
	else if(g_KeyInPtn="MR")	; S4)M-Oオン状態
	{
		if(g_MojiOnHold[0]<>"") {
			; 処理A 3キー判定
			g_Interval["RM"] := g_MojiTick[0] - g_OyaTick["R"]
			if(g_Interval["RM"] <= g_Interval["MR"])	; 文字キーaから親指キーsまでの時間は、親指キーsから文字キーbまでの時間よりも長い
			{
				Gosub, SendOnHoldM		; 保留キーの単独打鍵
			} else {
				Gosub, SendOnHoldMO		; 保留キーの同時打鍵
			}
		}
	}
	else if(g_KeyInPtn="ML")	; S4)M-Oオン状態
	{
		if(g_MojiOnHold[0]<>"") {
			; 処理A 3キー判定
			g_Interval["LM"] := g_MojiTick[0] - g_OyaTick["L"]
			if(g_Interval["LM"] <= g_Interval["ML"])	; 文字キーaから親指キーsまでの時間は、親指キーsから文字キーbまでの時間よりも長い
			{
				Gosub, SendOnHoldM		; 保留キーの単独打鍵
			} else {
				Gosub, SendOnHoldMO		; 保留キーの同時打鍵
			}
		}
	}
	else if(g_KeyInPtn="RM" || g_KeyInPtn="LM")		;S5)O-Mオン状態
	{
		if(g_MojiOnHold[0]<>"") {
			Gosub, SendOnHoldMO
		}
	}
	else if(g_KeyInPtn="RMr" || g_KeyInPtn="LMl")	;S6)O-M-Oオフ状態
	{
		if(g_MojiOnHold[0]<>"") {
			Gosub, SendOnHoldMO			; 同時打鍵
		}
	}
	SetKeyDelay, -1
	Gosub,ScanModifier
	if(g_Modifier != 0)		; 修飾キーが押されている
	{
		; 修飾キー＋文字キーの同時押しのときは、英数レイアウトで出力
		SendAN("AN" . KoyubiOrSans(g_Koyubi,g_sans), g_layoutPos)
		g_MojiOnHold[0]   := ""

		g_RomajiOnHold[0] := ""
		g_OyaOnHold[0]    := ""
		g_KoyubiOnHold[0] := ""
		g_SendTick := INFINITE
		g_KeyInPtn := ""
		critical,off
		return
	}
	Critical,5
	Gosub,ChkIME

	if(g_Oya = "N")
	{
		if(g_KeyInPtn = "") {
			; 当該キーを単独打鍵として保留
			g_MojiOnHold[0]   := g_layoutPos

			g_RomajiOnHold[0] := g_Romaji
			g_OyaOnHold[0]    := g_Oya
			g_KoyubiOnHold[0] := KoyubiOrSans(g_Koyubi,g_sans)
			g_KeyInPtn := "M"
			g_SendTick := g_MojiTick[0] + minimum(floor((g_Threshold*(100-g_OverlapMO))/g_OverlapMO),g_MaxTimeout)
			if(CountObject(g_SimulMode)!=0) {
				; 文字同時打鍵があればタイムアウトの大きい方に合わせる
				g_SendTick := maximum(g_SendTick, g_MojiTick[0] + minimum(floor((g_ThresholdSS*(100-g_OverlapSS))/g_OverlapSS),g_MaxTimeout))
			}
			SendZeroDelay(g_RomajiOnHold[0] . g_OyaOnHold[0] . g_KoyubiOnHold[0], g_MojiOnHold[0], g_ZeroDelay)
		}
		else if(g_KeyInPtn = "M")	; S2)Mオン状態
		{
			g_Interval["S12"]  := g_MojiTick[0] - g_MojiTick[1]	; 前回の文字キー押しからの期間

			g_MojiOnHold[1] := g_MojiOnHold[0]
			g_MojiOnHold[0] := g_layoutPos

			g_RomajiOnHold[1] := g_RomajiOnHold[0]
			g_RomajiOnHold[0] := g_Romaji

			g_OyaOnHold[1] := g_OyaOnHold[0]
			g_OyaOnHold[0] := g_Oya

			g_KoyubiOnHold[1] := g_KoyubiOnHold[0]
			g_KoyubiOnHold[0] := KoyubiOrSans(g_Koyubi,g_sans)
			; 当該キーとその前を同時打鍵として保留
			g_SendTick := g_MojiTick[0] + maximum(g_ThresholdSS,g_Threshold)
			g_KeyInPtn := "MM"
		}
		else if(g_KeyInPtn = "MM")	; MMオン状態
		{
			g_Interval["S12"]  := g_MojiTick[0] - g_MojiTick[1]	; 前回の文字キー押しからの期間

			g_MojiOnHold[2] := g_MojiOnHold[1]
			g_MojiOnHold[1] := g_MojiOnHold[0]
			g_MojiOnHold[0] := g_layoutPos

			g_RomajiOnHold[2] := g_RomajiOnHold[1]
			g_RomajiOnHold[1] := g_RomajiOnHold[0]
			g_RomajiOnHold[0] := g_Romaji

			g_OyaOnHold[2] := g_OyaOnHold[1]
			g_OyaOnHold[1] := g_OyaOnHold[0]
			g_OyaOnHold[0] := g_Oya

			g_KoyubiOnHold[2] := g_KoyubiOnHold[1]
			g_KoyubiOnHold[1] := g_KoyubiOnHold[0]
			g_KoyubiOnHold[0] := KoyubiOrSans(g_Koyubi,g_sans)
			; 当該キーとその前を同時打鍵として保留
			g_SendTick := g_MojiTick[0] + maximum(g_ThresholdSS,g_Threshold)
			g_KeyInPtn := "MMM"
		}
	}
	else
	{
		g_Interval[g_Oya . "M"] := g_MojiTick[0] - g_OyaTick[g_Oya]
		g_MojiOnHold[0]   := g_layoutPos
		g_RomajiOnHold[0] := g_Romaji
		g_OyaOnHold[0]    := g_Oya
		g_KoyubiOnHold[0] := KoyubiOrSans(g_Koyubi,g_sans)

		g_MojiCount[g_Oya] := g_MojiCount[g_Oya] + 1
		
		g_SendTick := g_MojiTick[0] + minimum(floor((g_Interval[g_Oya . "M"]*g_OverlapOM)/(100-g_OverlapOM)),g_Threshold)
		g_KeyInPtn := g_Oya . "M"
		SendZeroDelay(g_RomajiOnHold[0] . g_OyaOnHold[0] . g_KoyubiOnHold[0], g_MojiOnHold[0], g_ZeroDelay)
	}
	critical,off
	return


;----------------------------------------------------------------------
; 小指シフトとSanSの論理和
;----------------------------------------------------------------------
KoyubiOrSans(_Koyubi, _sans)
{
	if(_Koyubi=="K" || _sans=="K") 
	{
		return "K"
	}
	return "N"
}

;----------------------------------------------------------------------
; 元の109レイアウトで出力
;----------------------------------------------------------------------
SendAN(_mode,g_layoutPos)
{
	global mdn, mup, kup_save, g_LastKey
	
	vOut                  := mdn[_mode . g_layoutPos]
	kup_save[g_layoutPos] := mup[_mode . g_layoutPos]
	SubSend(vOut)
	g_LastKey["表層"] := ""
	g_LastKey["状態"] := ""
}
;----------------------------------------------------------------------
; キーをすぐさま出力
;----------------------------------------------------------------------
SendKey(_mode, _MojiOnHold){
	global kdn, kup, kup_save,kLabel
	global g_LastKey, kst, g_Koyubi
	
	vOut                  := kdn[_mode . _MojiOnHold]
	kup_save[_MojiOnHold] := kup[_mode . _MojiOnHold]
	_kLabel := kLabel[_mode . _MojiOnHold]
	_kst    := kst[_mode . _MojiOnHold]
	
	_nextKey := nextDakuten(_mode,_MojiOnHold)
	if(_nextKey != "") {
		g_LastKey["表層"] := _nextKey
		_aStr := "後" . kana2Romaji(g_LastKey["表層"])
		GenSendStr3(_aStr, _down, _up)
		vOut                  := _down
		kup_save[_MojiOnHold] := _up
		
		_kLabel := g_LastKey["表層"]
		_kst    := g_LastKey["状態"]
	} else {
		g_LastKey["表層"] := kLabel[_mode . _MojiOnHold]
		g_LastKey["状態"] := kst[_mode . _MojiOnHold]
	}
	if(g_Koyubi=="K" && _kst == "M") {
		vOut := "{capslock}" . vOut . "{capslock}"
	}	
	SubSend(vOut)
}
;----------------------------------------------------------------------
; 修飾キー押下
;----------------------------------------------------------------------
keydown:
keydownX:
	Critical
	GuiControl,2:,vkeyDN%g_layoutPos%,□
	g_trigger := g_metaKey

	RegLogs(kName . " down")
	gosub,Polling
	keyState[g_layoutPos] := Pf_Count()
	if(ShiftMode[g_Romaji] == "プレフィックスシフト") {
		SubSend(MnDown(kName))
		g_LastKey["表層"] := ""
		g_LastKey["状態"] := ""
		g_prefixshift := ""
		critical,off
		return
	}
	g_ModifierTick := keyState[g_layoutPos]
	
	Gosub,ModeInitialize
	SubSend(MnDown(kName))
	g_LastKey["表層"] := ""
	g_LastKey["状態"] := ""
	g_KeyInPtn := ""
	critical,off
	return

;----------------------------------------------------------------------
; スペース＆シフトキー押下
;----------------------------------------------------------------------
keydownS:
	Critical
	GuiControl,2:,vkeyDN%g_layoutPos%,□
	g_trigger := g_metaKey

	RegLogs(kName . " down")
	gosub,Polling
	keyState[g_layoutPos] := Pf_Count()

	g_ModifierTick := keyState[g_layoutPos]
	Gosub,ModeInitialize
	if(g_sans == "K") {
		SubSend(MnDown(kName))
	}
	g_sans := "K"
	g_sansTick := keyState[g_layoutPos] + g_MaxTimeout
	if(ShiftMode[g_Romaji] == "プレフィックスシフト") {
		g_prefixshift := ""
	} else {
		g_KeyInPtn := ""
	}
	critical,off
	return

;----------------------------------------------------------------------
; 月配列等のプレフィックスシフトキー押下
;----------------------------------------------------------------------
keydown1:
keydown2:
	Critical
	GuiControl,2:,vkeyDN%g_layoutPos%,□
	RegLogs(kName . " down")
	keyState[g_layoutPos] := Pf_Count()
	g_trigger := g_metaKey

	Gosub,ScanModifier
	if(g_Modifier != 0)		; 修飾キーが押されている
	{
		; 修飾キー＋文字キーの同時押しのときは、英数レイアウトで出力
		SendAN("AN" . KoyubiOrSans(g_Koyubi,g_sans), g_layoutPos)
		
		g_MojiOnHold[0]   := ""

		g_RomajiOnHold[0] := ""
		g_OyaOnHold[0]    := ""
		g_KoyubiOnHold[0] := ""
		g_SendTick := INFINITE
		g_KeyInPtn := ""

		g_prefixshift := ""
		critical,off
		return
	}
	if(g_prefixshift == "")
	{
		g_prefixshift := g_metaKey
		critical,off
		return
	}
	g_MojiOnHold[0]   := g_layoutPos
	g_RomajiOnHold[0] := g_Romaji
	g_OyaOnHold[0]    := g_prefixshift
	g_KoyubiOnHold[0] := KoyubiOrSans(g_Koyubi,g_sans)

	SendKey(g_RomajiOnHold[0] . g_OyaOnHold[0] . g_KoyubiOnHold[0], g_MojiOnHold[0])

	g_prefixshift := ""
	critical,off
	return


;----------------------------------------------------------------------
; 親指シフトと同時打鍵の零遅延モードの先行出力
;----------------------------------------------------------------------
SendZeroDelay(_mode, _MojiOnHold, g_ZeroDelay) {
	global g_ZeroDelaySurface, g_ZeroDelayOut, kup_save, kdn, kup, kLabel
	global g_LastKey, ctrlKeyHash, kst, g_Koyubi

	if(g_ZeroDelay == 1)
	{
		; 保留キーがあれば先行出力（零遅延モード）
		g_ZeroDelaySurface := kLabel[_mode . _MojiOnHold]

		; １文字通常出力の非制御コードならば先行出力
		if(kst[_mode . _MojiOnHold] == "M" && strlen(g_ZeroDelaySurface)==1 && ctrlKeyHash[g_ZeroDelaySurface]=="") {
			vOut                  := kdn[_mode . _MojiOnHold]
			kup_save[_MojiOnHold] := kup[_mode . _MojiOnHold]
			_kLabel := kLabel[_mode . _MojiOnHold]
			_kst    := kst[_mode . _MojiOnHold]			
			
			_nextKey := nextDakuten(_mode,_MojiOnHold)
			if(_nextKey!="") {
				_aStr := "後" . kana2Romaji(_nextKey)
				GenSendStr3(_aStr, _down, _up)
				vOut                  := _down
				kup_save[_MojiOnHold] := _up
				
				_kLabel := g_LastKey["表層"]
				_kst    := g_LastKey["状態"]
			}
			if(g_Koyubi=="K" && _kst == "M") {
				vOut := "{capslock}" . vOut . "{capslock}"
			}
			g_ZeroDelayOut := vOut
			SubSend(vOut)
		} else {
			g_ZeroDelaySurface := ""
		}
	}
	else
	{
		g_ZeroDelaySurface := ""
		g_ZeroDelayOut := ""
	}
	return
}
;----------------------------------------------------------------------
; 濁点・半濁点の処理
;----------------------------------------------------------------------
nextDakuten(_mode,_MojiOnHold)
{
	global g_LastKey, kLabel
	global DakuonSurfaceHash, HandakuonSurfaceHash, YouonSurfaceHash, CorrectSurfaceHash

	_nextKey := ""
	if(g_LastKey["状態"]=="M") {
		if(kLabel[_mode . _MojiOnHold]=="゛" || kLabel[_mode . _MojiOnHold]=="濁") {
			_nextKey := DakuonSurfaceHash[g_LastKey["表層"]]
		} else
		if(kLabel[_mode . _MojiOnHold]=="゜" || kLabel[_mode . _MojiOnHold]=="半") {
			_nextKey := HandakuonSurfaceHash[g_LastKey["表層"]]
		} else
		if(kLabel[_mode . _MojiOnHold]=="拗") {
			_nextKey := YouonSurfaceHash[g_LastKey["表層"]]
		} else
		if(kLabel[_mode . _MojiOnHold]=="修") {
			_nextKey := CorrectSurfaceHash[g_LastKey["表層"]]
		}
	}
	return _nextKey
}

;----------------------------------------------------------------------
; キーアップ（押下終了）
;----------------------------------------------------------------------
keyupM:
	Critical
	GuiControl,2:,vkeyDN%g_layoutPos%,　
	g_trigger := g_metaKeyUp[g_metaKey]

	RegLogs(kName . " up")
	gosub,Polling
	keyState[g_layoutPos] := 0
	g_MojiUpTick[1] := g_MojiUpTick[0]
	g_MojiUpTick[0] := Pf_Count()	;A_TickCount
	
	if(ShiftMode[g_Romaji] == "プレフィックスシフト" || ShiftMode[g_Romaji] == "小指シフト") {
		vOut := kup_save[g_layoutPos]
		SubSend(vOut)
		kup_save[g_layoutPos] := ""
		critical,off
		return
	}
	; 親指シフトの動作
	if(g_KeyInPtn = "M")	; Mオン状態
	{
		if(g_layoutPos == g_MojiOnHold[0]) {	; 保留キーがアップされた
			g_Interval["S1_1"] := g_MojiUpTick[0] - g_MojiTick[0]	; 前回の文字キー押しからの期間
			Gosub, SendOnHoldM
		}
	}
	else if(g_KeyInPtn == "MM")
	{
		if(g_layoutPos == g_MojiOnHold[1]) {
			g_Interval["S2_1"] := g_MojiUpTick[0] - g_MojiTick[0]	; 前回の文字キー押しからの期間
			vOverlap := floor((100*g_Interval["S2_1"])/(g_Interval["S12"]+g_Interval["S2_1"]))	; 重なり厚み計算
			if(g_OverlapSS <= vOverlap) {
				; S4)M1M2オンM1オフモードに遷移
				g_SendTick := g_MojiUpTick[0] + minimum(floor((g_Interval["S2_1"]*(100-g_OverlapSS))/g_OverlapSS) - g_Interval["S12"],g_MaxTimeout)
				g_SendTick := maximum(g_SendTick, g_MojiTick[0] + minimum(floor((g_Threshold*(100-g_OverlapMO))/g_OverlapMO),g_MaxTimeout))
				g_KeyInPtn := "MMm"
			} else {
				Gosub, SendOnHoldM2	; ２文字前を単独打鍵して確定
				; １文字前の待機
				g_SendTick := g_MojiTick[0] + minimum(floor((g_ThresholdSS*(100-g_OverlapSS))/g_OverlapSS),g_MaxTimeout)
				g_SendTick := maximum(g_SendTick, g_MojiTick[0] + minimum(floor((g_Threshold*(100-g_OverlapMO))/g_OverlapMO),g_MaxTimeout))
				g_KeyInPtn := "M"
			}
		} else
		if(g_layoutPos == g_MojiOnHold[0]) {
			g_Interval["S2_2"] := g_MojiUpTick[0] - g_MojiTick[0]	; 前回の文字キー押しからの期間
			Gosub, SendOnHoldMM
		}
	}
	else if(g_KeyInPtn == "MMm")
	{
		g_Interval["S_1_2"] := g_MojiUpTick[0] - g_MojiUpTick[1]	; 前回の文字キーオフからの期間
		vOverlap := floor((100*g_Interval["S2_1"])/(g_Interval["S2_1"]+g_Interval["S_1_2"]))	; 重なり厚み計算
		; 同時打鍵を確定
		if(g_OverlapSS <= vOverlap) {
			Gosub, SendOnHoldMM
		} else {
			Gosub, SendOnHoldM2
			Gosub, SendOnHoldM
		}
	}
	else if(g_KeyInPtn == "MMM")
	{
		; 同時打鍵を確定
		Gosub, SendOnHoldMMM
	}
	else if(g_KeyInPtn="MR")	; M-Oオン状態
	{
		if(g_layoutPos = g_MojiOnHold[0])	; 保留キーがアップされた
		{
			; 処理C
			g_Interval["M_M"] := g_MojiUpTick[0] - g_MojiTick[0]
			g_Interval["R_M"] := g_MojiUpTick[0] - g_OyaTick["R"]
			vOverlap := floor((100*g_Interval["R_M"])/g_Interval["M_M"])
			if(vOverlap < g_OverlapMO && g_Interval["R_M"] < g_Threshold)	; g_Tau
			{
				Gosub, SendOnHoldM
				g_SendTick := g_OyaTick["R"] + minimum(floor((g_Threshold*(100-g_OverlapOM))/g_OverlapOM),g_MaxTimeout)
			} else {
				Gosub, SendOnHoldMO
			}
		}
	}
	else if(g_KeyInPtn="ML")	; M-Oオン状態
	{
		if(g_layoutPos = g_MojiOnHold[0])	; 保留キーがアップされた
		{
			; 処理C
			g_Interval["M_M"] := g_MojiUpTick[0] - g_MojiTick[0]
			g_Interval["L_M"] := g_MojiUpTick[0] - g_OyaTick["L"]
			vOverlap := floor((100*g_Interval["L_M"])/g_Interval["M_M"])
			if(vOverlap < g_OverlapMO && g_Interval["L_M"] < g_Threshold)	; g_Tau
			{
				Gosub, SendOnHoldM
				g_SendTick :=  g_OyaTick["L"] + minimum(floor((g_Threshold*(100-g_OverlapOM))/g_OverlapOM),g_MaxTimeout)
			} else {
				Gosub, SendOnHoldMO
			}
		}
	}
	else if(g_KeyInPtn="RM" || g_KeyInPtn="LM")	; O-Mオン状態
	{
		if(g_layoutPos = g_MojiOnHold[0])	; 保留キーがアップされた
		{
			; 処理E
			Gosub, SendOnHoldMO
		}
	}
	else if(g_KeyInPtn="RMr" || g_KeyInPtn="LMl")	;O-M-Oオフ状態
	{
		if(g_layoutPos = g_MojiOnHold[0])	; 保留キーがアップされた
		{
			Gosub, SendOnHoldMO
		}
	}
	SubSend(kup_save[g_layoutPos])
	kup_save[g_layoutPos] := ""
	critical,off
	return


;----------------------------------------------------------------------
; 文字コード以外のキーアップ（押下終了）
;----------------------------------------------------------------------
keyup:
keyupX:
	Critical
	GuiControl,2:,vkeyDN%g_layoutPos%,　
	g_trigger := g_metaKeyUp[g_metaKey]

	RegLogs(kName . " up")
	gosub,Polling
	keyState[g_layoutPos] := 0
	g_MojiUpTick[0] := Pf_Count()	;A_TickCount
	vOut := MnUp(kName)
	SubSend(vOut)
	critical,off
	return

;----------------------------------------------------------------------
; スペース＆シフトキー（押下終了）
;----------------------------------------------------------------------
keyupS:
	Critical
	GuiControl,2:,vkeyDN%g_layoutPos%,　
	g_trigger := g_metaKeyUp[g_metaKey]

	RegLogs(kName . " up")
	gosub,Polling
	keyState[g_layoutPos] := 0
	g_MojiUpTick[0] := Pf_Count()	;A_TickCount
	if(g_sansTick != INFINITE) {
		SubSend(MnDown(kName))
	}
	g_sans := "N"
	vOut := MnUp(kName)
	SubSend(vOut)
	critical,off
	return

;----------------------------------------------------------------------
; 月配列等のプレフィックスシフトキー押下終了
;----------------------------------------------------------------------
keyup1:
keyup2:
	Critical
	GuiControl,2:,vkeyDN%g_layoutPos%,　
	g_trigger := g_metaKeyUp[g_metaKey]

	RegLogs(kName . " up")
	keyState[g_layoutPos] := 0
	SubSend(kup_save[g_layoutPos])
	kup_save[g_layoutPos] := ""
	critical,off
	return


;----------------------------------------------------------------------
; 10[mSEC]ごとの割込処理
;----------------------------------------------------------------------
Interrupt10:
	g_trigger := "TO"
	Gosub,ScanModifier
	;if(A_IsCompiled <> 1)
	;{
		;Tooltip, %g_Modifier%, 0, 0, 2 ; debug	
	;}
	if(g_Modifier!=0) 
	{
		Gosub,ModeInitialize
		SetHook("off","on")
	} else
	if(g_Pause==1) 
	{
		Gosub,ModeInitialize
		SetHook("off","off")
	} else {
		Gosub,ChkIME

		; 現在の配列面が定義されていればキーフック
		if(LF[g_Romaji . "N" . g_Koyubi]!="") {
			SetHook("on","on")
		} else {
			SetHook("off","on")
		}
	}
	if(keyState["A04"] != 0)
	{
		_TickCount := Pf_Count()	;A_TickCount
		if(_TickCount > keyState["A04"] + 100) 	; タイムアウト
		{
			; ひらがな／カタカナキーはキーアップを受信できないから、0.1秒でキーアップと見做す
			g_layoutPos := "A04"
			g_metaKey := keyAttribute3[g_Romaji . g_Koyubi . g_layoutPos]
			kName := keyNameHash[g_layoutPos]
			goto, keyup%g_metaKey%
		}
	}
	if(A_IsCompiled <> 1)
	{
		vImeMode := IME_GET() & 32767
		vImeConvMode := IME_GetConvMode()
		szConverting := IME_GetConverting()

		g_debugout2 := DllCall("GetAsyncKeyState", "UInt", 0x31)
		g_debugout := vImeMode . ":" . vImeConvMode . szConverting . ":" . g_Romaji . g_Oya . g_Koyubi g_layoutPos . ":" . g_debugout2
		;g_LastKey["status"] . ":" . g_LastKey["snapshot"]
		Tooltip, %g_debugout%, 0, 0, 2 ; debug
		
		g_S12Interval := g_Interval["S12"]
		g_S2_1Interval := g_Interval["S2_1"]
		g_S_1_2Interval := g_Interval["S_1_2"]
		;Tooltip, %g_S12Interval% %g_S2_1Interval% %g_S_1_2Interval% %g_debugout2%, 0, 0, 2 ; debug
		;Tooltip, DBG%g_S12Interval% %g_S2_1Interval% %g_S_1_2Interval%, 0, 0, 2 ; debug
		;if(ShiftMode["R"] == "文字同時打鍵" ) {
		;	g_S12Interval := g_Interval["S12"]
		;	g_S2_1Interval := g_Interval["S2_1"]
		;	g_S_1_2Interval := g_Interval["S_1_2"]
		;	;Tooltip, %g_S12Interval% %g_S2_1Interval% %g_S_1_2Interval%, 0, 0, 2 ; debug
		;	Tooltip, %g_debugout%, 0, 0, 2 ; debug
		;} else
		;if(ShiftMode["R"] == "親指シフト" ) {
		;	g_debugout := vImeMode . ":" . vImeConvMode . szConverting . ":" . g_Romaji . g_Oya . g_Koyubi . g_layoutPos . ":" . g_LastKey["status"] . ":" . g_LastKey["snapshot"] 
		;	Tooltip, %g_debugout%, 0, 0, 2 ; debug
		;} else {
		;	g_debugout := vImeMode . ":" . vImeConvMode . g_Romaji . g_Oya . g_Koyubi . g_layoutPos . "XXX[" . g_prefixshift . "]" . ShiftMode[g_Romaji]
		;	Tooltip, %g_debugout%, 0, 0, 2 ; debug
		;}
	}

Polling:
	if(g_SendTick <> "")
	{
		_TickCount := Pf_Count()	;A_TickCount
		if(_TickCount > g_SendTick) 	; タイムアウト
		{
			if g_KeyInPtn in M			; Mオン状態
			{
				Gosub, SendOnHoldM
			}
			else if g_KeyInPtn in MM
			{
				_mode := g_RomajiOnHold[0] . g_OyaOnHold[0] . g_KoyubiOnHold[0]
				if(ksc[_mode . g_MojiOnHold[0]]<=1 || (ksc[_mode . g_MojiOnHold[0]]<=2 && kdn[_mode . g_MojiOnHold[1] . g_MojiOnHold[0]]=="")) {
					Gosub, SendOnHoldM2
					Gosub, SendOnHoldM
				} else {
					Gosub, SendOnHoldMM
				}
			}
			else if g_KeyInPtn in MMm
			{
				Gosub, SendOnHoldM2
				Gosub, SendOnHoldM
			}
			else if g_KeyInPtn in MMM
			{
				Gosub, SendOnHoldMMM
			}
			else if g_KeyInPtn in L,R	; Oオン状態
			{
				; タイムアウトせずに留まる
				;if(g_Continue = 0)	; 連続モードではない
				;{
				;	g_Oya := "N"
				;}
				if(g_OyaKeyOn[g_Oya] == "sc039" || g_KeySingle == "有効") {
					Gosub, SendOnHoldO		; 保留親指キーの単独打鍵
				} else {
					_layout := g_Oya2Layout[g_Oya]
					_keyName := keyNameHash[_layout]
					if(GetKeyState(_keyName,"P") == 0) {
						Gosub, SendOnHoldO		; 保留親指キーの単独打鍵
					}
				}
			}
			else if g_KeyInPtn in ML,MR,RM,LM	; M-Oオン状態、O-Mオン状態
			{
				Gosub, SendOnHoldMO		; 保留キーの同時打鍵
			}
			else if g_KeyInPtn in RMr,LMl	; O-M-Oオフ状態
			{
				if(g_Continue = 0)		; 連続モードてはない
				{
					Gosub, SendOnHoldO		; 保留親指キーの単独打鍵
				}
				Gosub, SendOnHoldM		; 保留文字キーの単独打鍵
			}
		}
		if(_TickCount > g_sansTick) 	; タイムアウト
		{
			SubSend(MnDown(kName))
			g_sansTick := INFINITE
		}
	}
	return

ScanModifier:
	if(g_hookShift == "off") {
		stLShift := GetKeyStateWithLog(stLShift,160,"LShift")
		stRShift := GetKeyStateWithLog(stRShift,161,"RShift")
		if(stLShift!=0 || stRShift!=0)
		{
			g_Koyubi := "K"
		} else {
			g_Koyubi := "N"
		}
	}
	Critical
	g_Modifier := 0x00
	stLCtrl := GetKeyStateWithLog(stLCtrl,162,"LCtrl")
	g_Modifier := g_Modifier | stLCtrl
	g_Modifier := g_Modifier >> 1			; 0x02
	stRCtrl := GetKeyStateWithLog(stRCtrl,163,"RCtrl")
	g_Modifier := g_Modifier | stRCtrl
	g_Modifier := g_Modifier >> 1			; 0x04
	stLAlt  := GetKeyStateWithLog(stLAlt,164,"LAlt")
	g_Modifier := g_Modifier | stLAlt
	g_Modifier := g_Modifier >> 1			; 0x08
	stRAlt  := GetKeyStateWithLog(stRAlt,165,"RAlt")
	g_Modifier := g_Modifier | stRAlt
	g_Modifier := g_Modifier >> 1			; 0x10
	stLWin  := GetKeyStateWithLog(stLWin,91,"LWin")
	g_Modifier := g_Modifier | stLWin
	g_Modifier := g_Modifier >> 1			; 0x20
	stRWin  := GetKeyStateWithLog(stRWin,92,"RWin")
	g_Modifier := g_Modifier | stRWin
	g_Modifier := g_Modifier >> 1			; 0x40
	stAppsKey  := GetKeyStateWithLog(stApp,93,"AppsKey")
	g_Modifier := g_Modifier | stAppsKey	; 0x80
	
	stPause := GetKeyStateWithLog3(stPause,0x13,"Pause", _kDown)
	if(_kDown == 1 && g_KeyPause == "Pause") {
		Gosub,pauseKeyDown
	}
	stScrollLock := GetKeyStateWithLog3(stScrollLock,0x91,"ScrollLock",_kDown)
	if(_kDown == 1 && g_KeyPause == "ScrollLock") {
		Gosub,pauseKeyDown
	}
	if(g_KeyPause == "無効")
	{
		if(g_Pause == 1) {
			Gosub,pauseKeyDown
		}
	}
	critical,off
	return

ModeInitialize:
	if(g_KeyInPtn = "M")
	{
		Gosub, SendOnHoldM
	}
	else if(g_KeyInPtn == "MM")
	{
		_mode := g_RomajiOnHold[0] . g_OyaOnHold[0] . g_KoyubiOnHold[0]
		if(ksc[_mode . g_MojiOnHold[0]]<=1 || (ksc[_mode . g_MojiOnHold[0]]<=2 && kdn[_mode . g_MojiOnHold[1] . g_MojiOnHold[0]]=="")) {
			Gosub, SendOnHoldM2
			Gosub, SendOnHoldM
		} else {
			Gosub, SendOnHoldMM
		}
	}
	else if(g_KeyInPtn == "MMm")
	{
		Gosub, SendOnHoldM2
		Gosub, SendOnHoldM
	}
	else if(g_KeyInPtn == "MMM")
	{
		Gosub, SendOnHoldMMM
	}
	else if(g_KeyInPtn="L" || g_KeyInPtn="R")
	{
		Gosub, SendOnHoldO		; 保留キーの同時打鍵
	}
	else if(g_KeyInPtn="ML" || g_KeyInPtn="MR")
	{
		Gosub, SendOnHoldMO		; 保留キーの同時打鍵
	}
	else if(g_KeyInPtn="RM" || g_KeyInPtn="LM")
	{
		Gosub, SendOnHoldMO
	}
	else if(g_KeyInPtn="RMr" || g_KeyInPtn="LMl")
	{
		Gosub, SendOnHoldMO			; 同時打鍵
	}
	return

;-----------------------------------------------------------------------
;	仮想キーの状態取得とログ
;-----------------------------------------------------------------------
GetKeyStateWithLog(stLast, vkey0, kName) {
	;stCurr := DllCall("GetKeyState", "UInt", vkey0) & 128
	stCurr := DllCall("GetAsyncKeyState", "UInt", vkey0)
	if(stCurr !=0 && stLast = 0)	; keydown
	{
		RegLogs(kName . " down")
	}
	else if(stCurr = 0 && stLast !=0)	; keyup
	{
		RegLogs(kName . " up")
	}
	return stCurr
}
;-----------------------------------------------------------------------
;	仮想キーの状態取得とログ
;-----------------------------------------------------------------------
GetKeyStateWithLog3(stLast, vkey0, kName,byRef kDown) {
	kDown := 0
	;stCurr := DllCall("GetKeyState", "UInt", vkey0) & 128
	stCurr := DllCall("GetAsyncKeyState", "UInt", vkey0)
	if(stCurr != 0 && stLast == 0)	; keydown
	{
		kDown := 1
		RegLogs(kName . " down")
	}
	else if(stCurr == 0 && stLast != 0)	; keyup
	{
		RegLogs(kName . " up")
	}
	return stCurr
}

pauseKeyDown:
	if(g_Pause == 1) {
		Gosub, DoResume
	} else {
		Gosub, DoPause
	}
	return

;----------------------------------------------------------------------
; IME状態のチェックとローマ字モード判定
; 2019/3/3 ... IME_GetConvMode の上位31-15bitが立っている場合がある
;              よって、最下位ビットのみを見る
;----------------------------------------------------------------------
ChkIME:
	if(LF[g_Romaji . "NK"]=="" || g_Koyubi == "N") {		
		; 小指シフトオン時に、MS-IMEは英数モードを、Google日本語入力はローマ字モードを返す
		; 両方とも小指シフト面を反映させるため、変換モードは見ない
		; 小指シフト面が設定されていなければ変換モードを見る
		vImeMode := IME_GET() & 32767
		if(vImeMode = 0)
		{
			vImeConvMode :=IME_GetConvMode()
			g_Romaji := "A"
		} else {
			vImeConvMode :=IME_GetConvMode()
			if( vImeConvMode & 0x01 == 1) ;半角カナ・全角平仮名・全角カタカナ
			{
				g_Romaji := "R"
			}
			else ;ローマ字変換モード
			{
				g_Romaji := "A"
			}
		}
	}
	;if(A_IsCompiled <> 1)
	;{
		;vImeConverting := IME_GetConverting() & 32767
		;Tooltip, %g_Romaji% %vImeConvMode%, 0, 0, 2 ; debug
	;}
	return

;----------------------------------------------------------------------
; キーを押下されたときに呼び出されるGotoラベルにフックする
;----------------------------------------------------------------------
SetHookInit()
{
	Critical
	hotkey,*sc002,gSC002		;1
	hotkey,*sc002 up,gSC002up
	hotkey,*sc003,gSC003		;2
	hotkey,*sc003 up,gSC003up
	hotkey,*sc004,gSC004		;3
	hotkey,*sc004 up,gSC004up
	hotkey,*sc005,gSC005		;4
	hotkey,*sc005 up,gSC005up
	hotkey,*sc006,gSC006		;5
	hotkey,*sc006 up,gSC006up
	hotkey,*sc007,gSC007		;6
	hotkey,*sc007 up,gSC007up
	hotkey,*sc008,gSC008		;7
	hotkey,*sc008 up,gSC008up
	hotkey,*sc009,gSC009		;8
	hotkey,*sc009 up,gSC009up
	hotkey,*sc00A,gSC00A		;9
	hotkey,*sc00A up,gSC00Aup
	hotkey,*sc00B,gSC00B		;0
	hotkey,*sc00B up,gSC00Bup
	hotkey,*sc00C,gSC00C		;-
	hotkey,*sc00C up,gSC00Cup
	hotkey,*sc00D,gSC00D		;^
	hotkey,*sc00D up,gSC00Dup
	hotkey,*sc07D,gSC07D		;\
	hotkey,*sc07D up,gSC07Dup
	hotkey,*sc010,gSC010		;q
	hotkey,*sc010 up,gSC010up
	hotkey,*sc011,gSC011		;w
	hotkey,*sc011 up,gSC011up
	hotkey,*sc012,gSC012		;e
	hotkey,*sc012 up,gSC012up
	hotkey,*sc013,gSC013		;r
	hotkey,*sc013 up,gSC013up
	hotkey,*sc014,gSC014		;t
	hotkey,*sc014 up,gSC014up
	hotkey,*sc015,gSC015		;y
	hotkey,*sc015 up,gSC015up
	hotkey,*sc016,gSC016		;u
	hotkey,*sc016 up,gSC016up
	hotkey,*sc017,gSC017		;i
	hotkey,*sc017 up,gSC017up
	hotkey,*sc018,gSC018		;o
	hotkey,*sc018 up,gSC018up
	hotkey,*sc019,gSC019		;p
	hotkey,*sc019 up,gSC019up
	hotkey,*sc01A,gSC01A		;@
	hotkey,*sc01A up,gSC01Aup
	hotkey,*sc01B,gSC01B		;[
	hotkey,*sc01B up,gSC01Bup
	hotkey,*sc01E,gSC01E		;a
	hotkey,*sc01E up,gSC01Eup
	hotkey,*sc01F,gSC01F		;s
	hotkey,*sc01F up,gSC01Fup
	hotkey,*sc020,gSC020		;d
	hotkey,*sc020 up,gSC020up
	hotkey,*sc021,gSC021		;f
	hotkey,*sc021 up,gSC021up
	hotkey,*sc022,gSC022		;g
	hotkey,*sc022 up,gSC022up
	hotkey,*sc023,gSC023		;h
	hotkey,*sc023 up,gSC023up
	hotkey,*sc024,gSC024 		;j
	hotkey,*sc024 up,gSC024up
	hotkey,*sc025,gSC025 		;k
	hotkey,*sc025 up,gSC025up
	hotkey,*sc026,gSC026 		;l
	hotkey,*sc026 up,gSC026up
	hotkey,*sc027,gSC027 		;';'
	hotkey,*sc027 up,gSC027up
	hotkey,*sc028,gSC028 		;'*'
	hotkey,*sc028 up,gSC028up
	hotkey,*sc02B,gSC02B 		;']'
	hotkey,*sc02B up,gSC02Bup
	hotkey,*sc02C,gSC02C		;z
	hotkey,*sc02C up,gSC02Cup
	hotkey,*sc02D,gSC02D		;x
	hotkey,*sc02D up,gSC02Dup
	hotkey,*sc02E,gSC02E		;c
	hotkey,*sc02E up,gSC02Eup
	hotkey,*sc02F,gSC02F		;v
	hotkey,*sc02F up,gSC02Fup
	hotkey,*sc030,gSC030		;b
	hotkey,*sc030 up,gSC030up
	hotkey,*sc031,gSC031		;n
	hotkey,*sc031 up,gSC031up
	hotkey,*sc032,gSC032		;m
	hotkey,*sc032 up,gSC032up
	hotkey,*sc033,gSC033		;,
	hotkey,*sc033 up,gSC033up
	hotkey,*sc034,gSC034		;.
	hotkey,*sc034 up,gSC034up
	hotkey,*sc035,gSC035		;/
	hotkey,*sc035 up,gSC035up
	hotkey,*sc073,gSC073		;\
	hotkey,*sc073 up,gSC073up
	hotkey,*sc00F,gSC00F				; \t
	hotkey,*sc00F up,gSC00Fup
	hotkey,*sc01C,gSC01C			; \r
	hotkey,*sc01C up,gSC01Cup
	hotkey,*sc00E,gSC00E	; \b
	hotkey,*sc00E up,gSC00Eup
	hotkey,*sc029,gSC029		;半角／全角
	hotkey,*sc029 up,gSC029up
	hotkey,*sc070,gSC070		;ひらがな／カタカナ
	hotkey,*sc070 up,gSC070up
	
	;-----------------------------------------------------------------------
	; 機能：モディファイアキー
	;-----------------------------------------------------------------------
	;WindowsキーとAltキーをホットキー登録すると、
	;WindowsキーやAltキーの単体押しが効かなくなるのでコメントアウトする。
	;代わりにInterrupt10 でA_Priorkeyを見て、Windowsキーを監視する。
	;但し、WindowsキーやAltキーを離したことを感知できないことに留意。
	;ver.0.1.3 にて、GetKeyState でWindowsキーとAltキーとを監視
	;ver.0.1.3.7 ... Ctrlはやはり必要なので戻す
	;hotkey,LCtrl,gLCTRL
	;hotkey,LCtrl up,gLCTRLup
	;hotkey,RCtrl,gRCTRL
	;hotkey,RCtrl up,gRCTRLup
	
	Hotkey,*sc02A,gSC02A		; LShift
	Hotkey,*sc02A up,gSC02Aup
	Hotkey,*sc136,gSC136		; RShift
	Hotkey,*sc136 up,gSC136up
	
	Hotkey,*sc039,gSC039		; Space
	Hotkey,*sc039 up,gSC039up
	Hotkey,*sc079,gSC079
	Hotkey,*sc079 up,gSC079up
	Hotkey,*sc07B,gSC07B
	Hotkey,*sc07B up,gSC07Bup
	Critical,off
	return
}

;----------------------------------------------------------------------
; 動的にホットキーをオン・オフする
; flg : 文字キーと機能キー
; oya_flg : 親指キーかつ無変換またｈ変換
;----------------------------------------------------------------------
SetHook(flg,oya_flg)
{
	global ShiftMode, g_KeySingle, g_OyaKeyOn, g_MojiCount, g_Oya, g_Romaji, g_Koyubi
	Critical
	hotkey,*sc002,%flg%		;1
	hotkey,*sc002 up,%flg%
	hotkey,*sc003,%flg%		;2
	hotkey,*sc003 up,%flg%
	hotkey,*sc004,%flg%		;3
	hotkey,*sc004 up,%flg%
	hotkey,*sc005,%flg%		;4
	hotkey,*sc005 up,%flg%
	hotkey,*sc006,%flg%		;5
	hotkey,*sc006 up,%flg%
	hotkey,*sc007,%flg%		;6
	hotkey,*sc007 up,%flg%
	hotkey,*sc008,%flg%		;7
	hotkey,*sc008 up,%flg%
	hotkey,*sc009,%flg%		;8
	hotkey,*sc009 up,%flg%
	hotkey,*sc00A,%flg%		;9
	hotkey,*sc00A up,%flg%
	hotkey,*sc00B,%flg%		;0
	hotkey,*sc00B up,%flg%
	hotkey,*sc00C,%flg%		;-
	hotkey,*sc00C up,%flg%
	hotkey,*sc00D,%flg%		;^
	hotkey,*sc00D up,%flg%
	hotkey,*sc07D,%flg%		;\
	hotkey,*sc07D up,%flg%
	hotkey,*sc010,%flg%		;q
	hotkey,*sc010 up,%flg%
	hotkey,*sc011,%flg%		;w
	hotkey,*sc011 up,%flg%
	hotkey,*sc012,%flg%		;e
	hotkey,*sc012 up,%flg%
	hotkey,*sc013,%flg%		;r
	hotkey,*sc013 up,%flg%
	hotkey,*sc014,%flg%		;t
	hotkey,*sc014 up,%flg%
	hotkey,*sc015,%flg%		;y
	hotkey,*sc015 up,%flg%
	hotkey,*sc016,%flg%		;u
	hotkey,*sc016 up,%flg%
	hotkey,*sc017,%flg%		;i
	hotkey,*sc017 up,%flg%
	hotkey,*sc018,%flg%		;o
	hotkey,*sc018 up,%flg%
	hotkey,*sc019,%flg%		;p
	hotkey,*sc019 up,%flg%
	hotkey,*sc01A,%flg%		;@
	hotkey,*sc01A up,%flg%
	hotkey,*sc01B,%flg%		;[
	hotkey,*sc01B up,%flg%
	hotkey,*sc01E,%flg%	;a
	hotkey,*sc01E up,%flg%
	hotkey,*sc01F,%flg%		;s
	hotkey,*sc01F up,%flg%
	hotkey,*sc020,%flg%		;d
	hotkey,*sc020 up,%flg%
	hotkey,*sc021,%flg%		;f
	hotkey,*sc021 up,%flg%
	hotkey,*sc022,%flg%		;g
	hotkey,*sc022 up,%flg%
	hotkey,*sc023,%flg%		;h
	hotkey,*sc023 up,%flg%
	hotkey,*sc024,%flg% 	;j
	hotkey,*sc024 up,%flg%
	hotkey,*sc025,%flg% 	;k
	hotkey,*sc025 up,%flg%
	hotkey,*sc026,%flg% 	;l
	hotkey,*sc026 up,%flg%
	hotkey,*sc027,%flg% 	;';'
	hotkey,*sc027 up,%flg%
	hotkey,*sc028,%flg% 	;'*'
	hotkey,*sc028 up,%flg%
	hotkey,*sc02B,%flg% 	;']'
	hotkey,*sc02B up,%flg%
	hotkey,*sc02C,%flg%		;z
	hotkey,*sc02C up,%flg%
	hotkey,*sc02D,%flg%		;x
	hotkey,*sc02D up,%flg%
	hotkey,*sc02E,%flg%		;c
	hotkey,*sc02E up,%flg%
	hotkey,*sc02F,%flg%		;v
	hotkey,*sc02F up,%flg%
	hotkey,*sc030,%flg%		;b
	hotkey,*sc030 up,%flg%
	hotkey,*sc031,%flg%		;n
	hotkey,*sc031 up,%flg%
	hotkey,*sc032,%flg%		;m
	hotkey,*sc032 up,%flg%
	hotkey,*sc033,%flg%		;,
	hotkey,*sc033 up,%flg%
	hotkey,*sc034,%flg%		;.
	hotkey,*sc034 up,%flg%
	hotkey,*sc035,%flg%		;/
	hotkey,*sc035 up,%flg%
	hotkey,*sc073,%flg%		;\
	hotkey,*sc073 up,%flg%
	hotkey,*sc00F,%flg%
	hotkey,*sc00F up,%flg%
	hotkey,*sc01C,%flg%
	hotkey,*sc01C up,%flg%
	hotkey,*sc00E,%flg%
	hotkey,*sc00E up,%flg%
	hotkey,*sc029,%flg%
	hotkey,*sc029 up,%flg%
	hotkey,*sc070,%flg%		;ひらがな／カタカナ
	hotkey,*sc070 up,%flg%
	;hotkey,LCtrl,%flg%
	;hotkey,LCtrl up,%flg%
	;hotkey,RCtrl,%flg%
	;hotkey,RCtrl up,%flg%
	
	Hotkey,*sc039,%flg%
	Hotkey,*sc039 up,%flg%

	if(keyAttribute3[g_Romaji . g_Koyubi . "A01"]!="X") {
		Hotkey,*sc07B,%oya_flg%
		Hotkey,*sc07B up,%oya_flg%
	} else {
		Hotkey,*sc07B,off
		Hotkey,*sc07B up,off
	}
	if(keyAttribute3[g_Romaji . g_Koyubi . "A03"]!="X") {
		Hotkey,*sc079,%oya_flg%
		Hotkey,*sc079 up,%oya_flg%
	} else {
		Hotkey,*sc079,off
		Hotkey,*sc079 up,off
	}
	if(flg="off") {
		g_OyaKeyOn["R"] := ""
		g_OyaKeyOn["L"] := ""
		g_MojiCount["R"] := 0
		g_MojiCount["L"] := 0
		g_Oya := "N"
	}
	Critical,off
	return
}

SetHookShift(flg)
{
	Hotkey,*sc02A,%flg%		; LShift
	Hotkey,*sc02A up,%flg%
	Hotkey,*sc136,%flg%		; RShift
	Hotkey,*sc136 up,%flg%
	return
}

gSC02A:		; LShift
gSC136:		; RShift
	g_Koyubi := "K"
	return
gSC02Aup:
gSC136up:
	g_Koyubi := "N"
	return

gSC002:	;1
gSC003:	;2
gSC004:	;3
gSC005:	;4
gSC006:	;5
gSC007:	;6
gSC008:	;7
gSC009:	;8
gSC00A:	;9
gSC00B:	;0
gSC00C:	;-
gSC00D:	;^
gSC07D:	;\
;　Ｄ段目
gSC010:	;q
gSC011:	;w
gSC012:	;e
gSC013:	;r
gSC014:	;t
gSC015:	;y
gSC016:	;u
gSC017:	;i
gSC018:	;o
gSC019:	;p
gSC01A:	;@
gSC01B:	;[
; Ｃ段目
gSC01E:	;a
gSC01F:	;s
gSC020:	;d
gSC021:	;f
gSC022:	;g
gSC023:	;h
gSC024: ;j
gSC025: ;k
gSC026: ;l
gSC027: ;';'
gSC028: ;'*'
gSC02B: ;']'
;　Ｂ段目
gSC02C:	;z
gSC02D:	;x
gSC02E:	;c
gSC02F:	;v
gSC030:	;b
gSC031:	;n
gSC032:	;m
gSC033:	;,
gSC034:	;.
gSC035:	;/
gSC073:	;\

gSC00F:
gSC01C:	;Enter
gSC00E:	;\b
gSC029:	;半角／全角
;Ａ段目
gSC070:	;ひらがな／カタカナ
gSC039:
gSC07B:					; 無変換キー（左）
gSC079:				; 変換キー（右）
gLCTRL:
gRCTRL:
	g_layoutPos := layoutPosHash[A_ThisHotkey]
	g_metaKey := keyAttribute3[g_Romaji . KoyubiOrSans(g_Koyubi,g_sans) . g_layoutPos]
	kName := keyNameHash[g_layoutPos]
	goto, keydown%g_metaKey%

; Ｅ段目
gSC002up:
gSC003up:
gSC004up:
gSC005up:
gSC006up:
gSC007up:
gSC008up:
gSC009up:
gSC00Aup:
gSC00Bup:
gSC00Cup:
gSC00Dup:
gSC07Dup:
gSC010up:
; Ｄ段目
gSC011up:	;w
gSC012up:	;e
gSC013up:	;r
gSC014up:	;t
gSC015up:	;y
gSC016up:	;u
gSC017up:	;i
gSC018up:	;o
gSC019up:	;p
gSC01Aup:	;@
gSC01Bup:	;[
; Ｃ段目
gSC01Eup:	;a
gSC01Fup:	;s
gSC020up:	;d
gSC021up:	;f
gSC022up:	;g
gSC023up:	;h
gSC024up:	;j
gSC025up:	;k
gSC026up:	;l
gSC027up:	;;
gSC028up:	;*
gSC02Bup:	;]
; Ｂ段目
gSC02Cup:	;z
gSC02Dup:	;x
gSC02Eup:	;c
gSC02Fup:	;v
gSC030up:	;b
gSC031up:	;n
gSC032up:	;m
gSC033up:	;,
gSC034up:	;.
gSC035up:	;/
gSC073up:	;_

gSC00Fup:
gSC01Cup:	;Enter
gSC00Eup:
gSC029up:	;半角／全角
gSC070up:	;ひらがな／カタカナ
gSC039up:
gSC07Bup:
gSC079up:
	g_layoutPos := layoutPosHash[A_ThisHotkey]
	g_metaKey := keyAttribute3[g_Romaji . KoyubiOrSans(g_Koyubi,g_sans) . g_layoutPos]
	kName := keyNameHash[g_layoutPos]
	goto, keyup%g_metaKey%

