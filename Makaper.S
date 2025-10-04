

	;===============================================.
	;						|
	; 		    MAKAPER			(
	;						|
	*-----------------------------------------------+
	; by Photon of Scoopex © 2025 Henrik Erlandsson	|
	*=========#=====================================#
	; 1.7:	  | Handle 1 param and params with "	|
	; 1.6:	  | Remove empty line before ENDM	|
	; 1.5:	  | Opt. last param autosave-> ResultVar|
	; 1.4:	  | LOADF error handling fix		|
	; 1.3:	  | Dynamic INIT,OPENLIBS,CALL+MAK_move	|
	; 1.2:	  | Size opti & improve NUMDECf		|
	; 1.1:	  | Refactor, bugfix WRITEF, added COPYS|
	*---------+-------------------------------------*
	; Notes: /
	*-------*

;A mini macro language for OS functions with zero dependendies*, includable
;anywhere. Always distribute with TestMakaper.S and test.txt to "unit" test
;each release!

;Use it to have common OS functions optional yet always at hand for things
;like CLI/Shell, I/O, file/string/number processing, and quick and easy
;calls with any library.

;Features:
; - Dynamic init, opening and closing of libraries, and lib calls.
; - One-liner loading of multiple registers.
; - Fewer lines of more readable code for common, dull tasks.
; - Does not add any code/modify the binary unless a function is used.
; - Has reasonably (size) optimized code.
; - Moderate sanity check on parameters e.g. 0-check on MAK_FREE to allow
;   cleanup/non-guru exit with multiple deallocs on the same alloc. It's on you
;   to clear ptrs/handles etc if you clean up before handling exit conditions.

;MAK_GETPARAMS takes parameter for max # of recognized parameters.
;MAK_INIT takes parameter for buffer size for text operations, with optional
;parameter to initialize the buffer with some useful text.

;* Declare global label R at maximum distance 32766 from start of program to
;maximize all PC-relative addressing modes for an executable of up to 64K.

;Follows OS standard of preserving d4-d7/a2-a6 where applicable.
;a5=global label R (for PC-relative code)
;a6=Execbase
;^ these are set automatically by MAK_INIT and MAK_CloseLibs. Between these
;calls, YOU are responsible for preserving them (normally only a5)!

;MAK_move is intended for use together with MAK_CALL to compact the number
;of code lines for typical library calls by a factor of up to 7:2.

MAK_move.w:MACRO	;value,reg[,value,reg...] (data regs .w)
	IFGE ($\2-$d0)
	move.w \1,\2
	ELSE
	move.l \1,\2
	ENDC

	IFNB \3
	IFGE ($\4-$d0)
	move.w \3,\4
	ELSE
	move.l \3,\4
	ENDC
	ENDC

	IFNB \5
	IFGE ($\6-$d0)
	move.w \5,\6
	ELSE
	move.l \5,\6
	ENDC
	ENDC

	IFNB \7
	IFGE ($\8-$d0)
	move.w \7,\8
	ELSE
	move.l \7,\8
	ENDC
	ENDC
	ENDM


MAK_move.l:MACRO	;value,reg[,value,reg...] (data regs .w)
	move.l \1,\2

	IFNB \3
	move.l \3,\4
	ENDC

	IFNB \5
	move.l \5,\6
	ENDC

	IFNB \7
	move.l \7,\8
	ENDC
	ENDM


MAK_CALL:MACRO				;libname,offset[,result dst .l]
	IFNC \1,exec
	move.l MAK_\1Base-R(a5),a6
	ELSE
	move.l 4.w,a6
	ENDC
	jsr \2(a6)
	IFNC \1,exec
	move.l 4.w,a6
	ENDC

	IFNB \3
	move.l d0,\3
	ELSE
	tst.l d0
	ENDC
	ENDM				;D0 TESTED AT EXIT!


MAK_INIT:MACRO				;TxtBuf size[,arbitrary string]
	lea R(PC),a5			;base reg (for opti)(MAX 64K CODE!)
	move.l 4.w,a6
;	move.b #" ",-1(a0,d0.w)		;make consistent. is asciiz.
	move.l a0,MAK_ParamP-R(A5)	;Paramstr ptr
	bra.s MAK_INITs
MAK_ParamP:	dc.l 0
MAK_InHdl:	dc.l 0			;handle for e.g. MAK_READLN
MAK_OutHdl:	dc.l 0			;handle for e.g. MAK_WRITELN
MAK_TxtBuf:
	IFNB \2
	dc.b \2
	ENDC
MAK_TxtMsgE:
	IF (\1-(MAK_TxtMsgE-MAK_TxtBuf))>0
	dcb.b (\1-(MAK_TxtMsgE-MAK_TxtBuf)),0
	ELSE
	dc.b 0			;ensure ASCIIZ
	ENDC
MAK_TxtBufE:
	EVEN
MAK_INITs:
	ENDM


;The only Makaper macro that can be called before MAK_INIT
MAK_FAKEPARAMS:MACRO			;"string". Fakes a DOS ParamStr.
	lea ._Fake(PC),a0		;PC because a5 not yet set!
	moveq #._FakeE-._Fake,d0
	bra.s ._FPs
._Fake:	dc.b \1,10
._FakeE:
	EVEN
._FPs:
	ENDM

MAK_GP:SET 0
MAK_GETPARAMS:MACRO		;#ParamLine(->ASCIIZ),Max no. of Params
	IFNC \1,a0
	move.l \1,a0
	ENDC
	moveq #\2,d0
	IF MAK_GP=1
	jsr MAK_GETPARAMSf-R(A5)
	ELSE
MAK_GP:SET 1
	bsr.s MAK_GETPARAMSf
	bra.s MAK_GPs

MAK_GETPARAMSf:
	move.l a2,-(SP)
	lea MAK_Params-R(a5),a1
	move.w d0,d2
	moveq #0,d0			;#actual params
._GP1:
	move.l a0,a2			;param start ptr
	moveq #0,d3			;reset quote flag
._GP2:
	move.b (a0)+,d1
	beq.s ._GPdone			;error (in this loop), quit
	cmp.b #34,d1			;quote toggles quote flag
	bne.s .GP_noq0
	not.w d3
.GP_noq0:
	tst.w d3			;quote flag set? then ignore space
	bne.s ._GP2
	cmp.b #" ",d1			;space or below?
	bhi.s ._GP2			;no, keep reading param chars
._GP3:
	subq.w #1,a0			;stop ptr of param (space/LF)
	cmp.l a2,a0
	beq.s ._GPparamDone		;if param len=0, don't count it.
	cmp.b #34,(a2)			;starts with "? 
	bne.s ._GPnoq1
	addq.w #1,a2			;then point to after "
._GPnoq1:
	cmp.b #34,-(a0)			;ended with "?
	bne.s ._GPnoq2
	clr.b (a0)			;then overwrite " with 0 to terminate
._GPnoq2:
	addq.w #1,a0
	move.l a2,(a1)+			;store pointer
	addq.w #1,d0			;and increase actual count
._GPparamDone:
	clr.b (a0)+			;space/LF -> 0 (terminate param)
	cmp.b #10,d1			;was separator LF/0, not space?
	bls.s ._GPdone			;then end of param string.
	subq.w #1,d2			;else loop until maxparams read.
	bne.s ._GP1
._GPdone:
	move.l (SP)+,a2
	tst.w d0
	RTS				;-> d0=#params (EQ=0)
MAK_Params:
	dcb.l \2,0			;max n Params (ptrs)
MAK_GPs:
	ENDC
	ENDM				;(EQ=NONE), D0.l=actual #params


MAK_OPENLIBS:MACRO	;up to 9 libnames -> d0=0 if error else last libbase.
.n:	SET 0
	lea MAK_LibBases-R(a5),a2
	IFNB \1
.n:	SET .n+1
	lea MAK_\1Name-R(A5),a1
	bsr.s ._OL1
	ENDC

	IFNB \2
.n:	SET .n+1
	lea MAK_\2Name-R(A5),a1
	bsr.s ._OL1
	ENDC

	IFNB \3
.n:	SET .n+1
	lea MAK_\3Name-R(A5),a1
	bsr.s ._OL1
	ENDC

	IFNB \4
.n:	SET .n+1
	lea MAK_\4Name-R(A5),a1
	bsr.s ._OL1
	ENDC

	IFNB \5
.n:	SET .n+1
	lea MAK_\5Name-R(A5),a1
	bsr.s ._OL1
	ENDC

	IFNB \6
.n:	SET .n+1
	lea MAK_\6Name-R(A5),a1
	bsr.s ._OL1
	ENDC

	IFNB \7
.n:	SET .n+1
	lea MAK_\7Name-R(A5),a1
	bsr.s ._OL1
	ENDC

	IFNB \8
.n:	SET .n+1
	lea MAK_\8Name-R(A5),a1
	bsr.s ._OL1
	ENDC

	IFNB \9
.n:	SET .n+1
	lea MAK_\9Name-R(A5),a1
	bsr.s ._OL1
	ENDC
._OL2:
	tst.l d0

	IF .n>4
	BRA MAK_OLs
	ELSE
	BRA.S MAK_OLs
	ENDC

._OL1:	jsr -408(a6)			;OldOpenLibrary
	move.l d0,(a2)+
	beq.s ._OL3
	RTS
._OL3:	addq.w #4,SP			;emulate rts
	bra.s ._OL2

MAK_LibBases:
	IFNB \1
MAK_\1Base:dc.l 0
	ENDC

	IFNB \2
MAK_\2Base:dc.l 0
	ENDC

	IFNB \3
MAK_\3Base:dc.l 0
	ENDC

	IFNB \4
MAK_\4Base:dc.l 0
	ENDC

	IFNB \5
MAK_\5Base:dc.l 0
	ENDC

	IFNB \6
MAK_\6Base:dc.l 0
	ENDC

	IFNB \7
MAK_\7Base:dc.l 0
	ENDC

	IFNB \8
MAK_\8Base:dc.l 0
	ENDC

	IFNB \9
MAK_\9Base:dc.l 0
	ENDC
MAK_LibBasesE:

	IFNB \1
MAK_\1Name:dc.b "\1.library",0
	EVEN
	ENDC

	IFNB \2
MAK_\2Name:dc.b "\2.library",0
	EVEN
	ENDC

	IFNB \3
MAK_\3Name:dc.b "\3.library",0
	EVEN
	ENDC

	IFNB \4
MAK_\4Name:dc.b "\4.library",0
	EVEN
	ENDC

	IFNB \5
MAK_\5Name:dc.b "\5.library",0
	EVEN
	ENDC

	IFNB \6
MAK_\6Name:dc.b "\6.library",0
	EVEN
	ENDC

	IFNB \7
MAK_\7Name:dc.b "\7.library",0
	EVEN
	ENDC

	IFNB \8
MAK_\8Name:dc.b "\8.library",0
	EVEN
	ENDC

	IFNB \9
MAK_\9Name:dc.b "\9.library",0
	EVEN
	ENDC

MAK_OLs:
	ENDM				;EQ=ERROR!


MAK_CLOSELIBS:MACRO			;closes any opened libs
	MOVEM.L D4/A2,-(SP)
	lea R(PC),a5
	move.l 4.w,a6
	lea MAK_LibBases-R(a5),a2
	moveq #(MAK_LibBasesE-MAK_LibBases)>>2-1,d4
._CLl:	move.l (a2)+,d0
	beq.s ._CLn
	move.l d0,a1
	jsr -414(a6)			;CloseLib
._CLn:	dbf d4,._CLl
	MOVEM.L (SP)+,D4/A2
	ENDM


MAK_IO:	MACRO
	MAK_CALL dos,-54		;DInput
	move.l d0,MAK_InHdl-R(A5)
	MAK_CALL dos,-60		;DOutput
	move.l d0,MAK_OutHdl-R(A5)
.err:
	ENDM				;EQ=no OutHdl


MAK_LK:	SET 0
MAK_LOCK:MACRO				;#Name,#Accessmode(_AccR or _AccW)
	IFNC \1,d1
	move.l \1,d1
	ENDC
	IFNC \2,d0
	moveq \2,d0
	ENDC
	IF MAK_LK=1
	jsr MAK_LOCKf-R(A5)
	ELSE
MAK_LK:	SET 1
	bsr.s MAK_LOCKf
	bra.s MAK_LKs
MAK_LOCKf:
	MOVE.L A6,-(SP)
	move.l MAK_dosBase-R(a5),a6
	move.l d0,d2
	jsr -84(a6)			;Lock
	MOVE.L (SP)+,A6
	RTS
MAK_LKs:
	ENDC
	ENDM				;D0=lock (0=ERROR)


MAK_UL:SET 0
MAK_UNLOCK:MACRO			;#Lock
	IFNC \1,d1
	move.l \1,d1
	ENDC
	IF MAK_UL=1
	jsr MAK_UNLOCKf-R(A5)
	ELSE
MAK_UL:SET 1
	bsr.s MAK_UNLOCKf
	bra.s MAK_ULs
MAK_UNLOCKf:
	MOVE.L A6,-(SP)
	move.l MAK_dosBase-R(a5),a6
	jsr -90(a6)			;UnLock
	MOVE.L (SP)+,A6
	RTS

MAK_ULs:ENDC
	ENDM


MAK_XM:SET 0
MAK_EXAMINE:MACRO			;#Lock,#InfoDestAddr
	IFNC \1,d1
	move.l \1,d1
	ENDC
	IFNC \2,d0
	move.l \2,d0
	ENDC
	IF MAK_XM=1
	jsr MAK_EXAMINEf-R(A5)
	ELSE
MAK_XM:SET 1
	bsr.s MAK_EXAMINEf
	bra.s MAK_XMs
MAK_EXAMINEf:
	MOVE.L A6,-(SP)
	move.l MAK_dosBase-R(a5),a6
	move.l d0,d2
	jsr -102(a6)			;Examine
	MOVE.L (SP)+,A6
	tst.l d0
	RTS
MAK_XMs:
	ENDC
	ENDM				;EQ=ERROR!


MAK_OF:SET 0
MAK_OPENF:MACRO			;#Handle,#NAMEADDR,#ACCESSMODE(_RW/_OLD/_NEW)
	IFNC \2,d1
	move.l \2,d1			;file name adr
	ENDC
	IFNC \3,d0
	move.w \3,d0			;mode
	ENDC
	IF MAK_OF=1
	jsr MAK_OPENFf-R(A5)
	move.l d0,\1
	ELSE
MAK_OF:SET 1
	bsr.s MAK_OPENFf
	bra.s MAK_OFs
MAK_OPENFf:

	MOVEM.L D2/A6,-(SP)
	move.l MAK_dosBase-R(A5),a6
	moveq #0,d2
	move.w d0,d2
	jsr -30(a6)			;open
	MOVEM.L (SP)+,D2/A6
	RTS
MAK_OFs:
	ENDC
	move.l d0,\1
	ENDM				;EQ=ERROR! (D0=HANDLE!)


MAK_CF:SET 0
MAK_CLOSEF:MACRO			;#Handle->d1
	move.l \1,d1
	IF MAK_CF=1
	beq.s ._CFs
	jsr MAK_CLOSEFf-R(A5)
._CFs:
	ELSE
MAK_CF:	SET 1
	beq.s MAK_CFs
	bsr.s MAK_CLOSEFf
	bra.s MAK_CFs
MAK_CLOSEFf:
	MAK_CALL dos,-36
	RTS
MAK_CFs:
	ENDC
	ENDM


MAK_RF:SET 0
MAK_READF:MACRO				;#Handle,#Addr,#Len[,#ResultVar]
	IFNC \1,d1
	move.l \1,d1			;file handle
	ENDC
	IFNC \3,a0
	move.l \3,a0			;len (OBS! a0!)
	ENDC
	IFNC \2,d0
	move.l \2,d0			;addr
	ENDC
	IF MAK_RF=1
	jsr MAK_READFf-R(A5)
	ELSE
MAK_RF:SET 1
	bsr.s MAK_READFf
	bra.s MAK_RFs
MAK_READFf:
	MOVEM.L D2-D3/A0/A6,-(SP)
	move.l MAK_dosBase-R(A5),a6
	move.l d0,d2
	move.l a0,d3
	jsr -42(a6)			;read
	MOVEM.L (SP)+,D2-D3/A0/A6
	cmp.l a0,d0
	RTS
MAK_RFs:
	ENDC

	IFNB \4
	move.l d0,\4
	cmp.l a0,d0
	ENDC
	ENDM				;(NE=ERROR!),D0=#BYTES ACTUALLY READ!


MAK_RL:SET 0
MAK_READLN:MACRO	;[#Handle][,#ResultVar]. Reads to MAK_TxtBuf&clrs last!
	IF MAK_RL=1
	jsr MAK_READLNf-R(A5)
	ELSE
MAK_RL:SET 1
	bsr.s MAK_READLNf
	bra.s MAK_RLs
MAK_READLNf:
	MOVEM.L D2/A2,-(SP)
	lea MAK_TxtBuf-R(a5),a2
	IF (MAK_TxtBufE-MAK_TxtBuf)<128
	moveq #(MAK_TxtBufE-MAK_TxtBuf),d2
	ELSE
	move.l #(MAK_TxtBufE-MAK_TxtBuf),d2
	ENDC
	IFNB \1
	MAK_READF \1,a2,d2
	ELSE
	MAK_READF MAK_InHdl-R(a5),a2,d2
	ENDC
	cmp.w d2,d0
	bge.s ._RL1
	subq.w #1,d0
	clr.b (a2,d0.w)
._RL1:	MOVEM.L (SP)+,D2/A2
	RTS
MAK_RLs:
	ENDC

	IFNB \2
	move.l d0,\2
	ELSE
	tst.l d0
	ENDC
	ENDM				;D0=#BYTES READ (LE=ERROR!)


MAK_WF:SET 0
MAK_WRITEF:MACRO			;#Handle,#Addr,#Len[,#ResultVar]
	IFNC \1,d1
	move.l \1,d1			;file handle
	ENDC
	IFNC \2,d2
	move.l \2,d2			;addr
	ENDC
	IFNC \3,d3
	move.l \3,d3
	ENDC
	IF MAK_WF=1
	jsr MAK_WRITEFf-R(A5)
	ELSE
MAK_WF:SET 1
	bsr.s MAK_WRITEFf
	bra.s MAK_WFs
MAK_WRITEFf:
	MOVEM.L D3/A6,-(SP)
	move.l MAK_dosBase-R(A5),a6
	jsr -48(a6)			;write
	MOVEM.L (SP)+,D3/A6
	cmp.l d3,d0
	RTS
MAK_WFs:
	ENDC

	IFNB \4
	move.l d0,\4
	cmp.l d3,d0
	ENDC
	ENDM				;(NE=ERROR!),D0=#BYTES ACTUALLY WRITTEN


MAK_WRITE:MACRO				;"Text" or Ascii-byte[,#ResultVar]
	bra.s MAK_WR1\@
MAK_WR2\@:	dc.b \1
MAK_WR3\@:
	EVEN
MAK_WR1\@:
	lea MAK_WR2\@-R(A5),a1
	IFNB \2
	MAK_WRITEF MAK_OutHdl-R(A5),a1,#MAK_WR3\@-MAK_WR2\@,\2
	ELSE
	MAK_WRITEF MAK_OutHdl-R(A5),a1,#MAK_WR3\@-MAK_WR2\@
	ENDC
	ENDM				;D0=#BYTES ACTUALLY WRITTEN (LE=ERROR!)


MAK_WRITELN:MACRO			;"Text" or Ascii-byte[,#ResultVar]
	bra.s MAK_WL1\@
MAK_WL2\@:
	IFNB \1
	dc.b \1,10
	ELSE
	dc.b 10
	ENDC
MAK_WL3\@:
	EVEN
MAK_WL1\@:
	lea MAK_WL2\@-R(A5),a1
	IFNB \2
	MAK_WRITEF MAK_OutHdl-R(A5),a1,#MAK_WL3\@-MAK_WL2\@,\2
	ELSE
	MAK_WRITEF MAK_OutHdl-R(A5),a1,#MAK_WL3\@-MAK_WL2\@
	ENDC
	ENDM				;D0=#BYTES ACTUALLY WRITTEN (LE=ERROR!)


MAK_WRA:SET 0
MAK_WRITEA:MACRO		;#TextPtr to 0-terminated string,[#ResultVar]
	IFNC \1,a0
	move.l \1,a0
	ENDC
	IF MAK_WRA=1
	jsr MAK_WRITEAf-R(A5)
	ELSE
MAK_WRA:SET 1
	bsr.s MAK_WRITEAf
	bra.s MAK_WRAs
MAK_WRITEAf:
	move.l a0,a1
._WRA1:	tst.b (a0)+
	bne.s ._WRA1
	subq.w #1,a0			;don't write the asciiz 0
	sub.l a1,a0
	MAK_WRITEF MAK_OutHdl-R(A5),a1,a0
	RTS
MAK_WRAs:
	ENDC
	IFNB \2
	move.l d0,\2
	ELSE
	tst.l d0
	ENDC
	ENDM				;D0=#BYTES ACTUALLY WRITTEN


MAK_WLA:SET 0
MAK_WRITELNA:MACRO		;#TextPtr to 0-terminated string[,#ResultVar]
	IFNC \1,a0
	move.l \1,a0
	ENDC
	IF MAK_WLA=1
	jsr MAK_WRITELNAf-R(A5)
	ELSE
MAK_WLA:SET 1
	bsr.s MAK_WRITELNAf
	bra.s MAK_WLAs
MAK_WRITELNAf:
	move.l a0,a1
._WLA1:	tst.b (a0)+
	bne.s ._WLA1
	move.b #10,-1(a0)
	MOVE.L A0,-(SP)
	sub.l a1,a0
	MAK_WRITEF MAK_OutHdl-R(A5),a1,a0
	MOVE.L (SP)+,A0
	clr.b -(a0)
	tst.l d0
	RTS
MAK_WLAs:
	ENDC

	IFNB \2
	move.l d0,\2
	ENDC
	ENDM				;D0=#BYTES ACTUALLY WRITTEN


MAK_CS:	SET 0	;Copies ASCIIZ string, replacing 0-31/128-159 with space.
MAK_COPYS:MACRO
	IFNC \1,a0
	move.l \1,a0
	ENDC
	IFNC \2,a1
	move.l \2,a1
	ENDC

	IF MAK_CS=1
	jsr MAK_COPYSf-R(A5)
	ELSE
MAK_CS:	SET 1
	bsr.s MAK_COPYSf
	bra.s MAK_CSs
MAK_COPYSf:
	moveq #32,d2
.l:	move.b (a0)+,d0
	beq.s .done
	moveq #$7f,d1
	and.b d0,d1
	cmp.b d2,d1
	bhs.s .ok
	moveq #" ",d0
.ok:	move.b d0,(a1)+
	bra.s .l
.done:
	clr.b (a1)+			;copy includes the zero
	RTS
MAK_CSs:
	ENDC
	ENDM


MAK_LD:SET 0
MAK_LOADF:MACRO				;#Name,MemType (uses FileHdl)
	IFNC \1,d0
	move.l \1,d0
	ENDC
	moveq #\2,d1
	IF MAK_LD=1
	jsr MAK_LOADFf-R(A5)
	ELSE
MAK_LD:SET 1
	bsr.s MAK_LOADFf
	bra MAK_LDs
MAK_LOADFf:
	MOVEM.L D2-D7/A2-A4/A6,-(SP)
	move.l 4.w,a6
	move.l MAK_dosBase-R(a5),a4
	moveq #-1,d6			;default error-reg (- = allocErr!)
	move.l d0,a3			;nameadr
	move.l d1,a2			;memtype!
	move.l #260,d0
	jsr -198(a6)			;AllocMem
	move.l d0,d4			;memaddr
	beq.w ._LDe
	moveq #0,d6			;no alloc error, default file error
	move.l a3,d1
	moveq #-2,d2			;_AccR
	exg a4,a6			;switch to DOS!
	jsr -84(a6)			;Lock
	move.l d0,d5
	beq.s ._LDd
	move.l d5,d1
	move.l d4,d2
	jsr -102(a6)			;Examine
	tst.l d0
	beq.s ._LDu
	move.l d4,a0
	move.l 124(a0),d7		;file size!
	beq.s ._LDu
	moveq #1,d6			;non-zero -- succeeded!
._LDu:	move.l d5,d1
	jsr -90(a6)			;UnLock
._LDd:	exg a4,a6			;switch to exec!
	move.l #260,d0			;opti!
	move.l d4,a1
	jsr -210(a6)			;freemem
	tst.l d6
	beq.s ._LDe

	moveq #-2,d6			;-=alloc err
	move.l d7,d0
	move.l a2,d1			;memtype
	jsr -198(a6)			;AllocMem
	move.l d0,d4			;memaddr
	beq.s ._LDe
	moveq #0,d6			;0=FILEERR!
	exg a4,a6			;DOS!
	move.l a3,d1
	move.l #1005,d2
	jsr -30(a6)			;open
	move.l d0,d5			;file handle
	beq.s ._LD2
	move.l d5,d1			;filehdl
	move.l d4,d2			;addr
	move.l d7,d3			;maxlen
	jsr -42(a6)			;read
	cmp.l d7,d0
	bne.s ._LDc
	move.l d7,d6			;loading ok! (set to size!)
._LDc:	move.l d5,d1
	jsr -36(a6)			;close!
._LD2:	move.l d6,d0
	bne.s ._LDo			;ok? then don't dealloc!
	exg a4,a6			;EXEC!
	move.l d7,d0
	move.l d4,a1
	jsr -210(a6)			;freemem
._LDe:	move.l d6,d0			;len(auto-tst!)
._LDo:	move.l d4,a0
	MOVEM.L (SP)+,D2-D7/A2-A4/A6
	RTS
MAK_LDs:
	ENDC
	ENDM			;(-=ALLOCERR,0=FILEERR!), A0=ALLOC-ADDR,D0=LEN!


MAK_AL:SET 0
MAK_ALLOC:MACRO		;#Size,Type(1/2/4/$20000=P/C/F/Largest)[,#ResultVar]
	IFNC \1,d0
	move.l \1,d0
	ENDC
	IF \2<128
	moveq #\2,d1
	ELSE
	move.l #\2,d1
	ENDC
	IF MAK_AL=1
	jsr MAK_ALLOCf-R(A5)
	ELSE
MAK_AL:SET 1
	bsr.s MAK_ALLOCf
	bra.s MAK_ALs
MAK_ALLOCf:
	MOVE.L A6,-(SP)
	move.l 4.w,a6
	jsr -198(a6)			;AllocMem
	MOVE.L (SP)+,A6
	tst.l d0
	RTS
MAK_ALs:
	ENDC

	IFNB \3
	move.l d0,\3
	ENDC
	ENDM				;EQ=ERROR,D0=MemAddr


MAK_FR:SET 0
MAK_FREE:MACRO				;#MemAddr,#Size
	move.l \1,d1
	beq.s MAK_FRskip\@
	move.l \2,d0
	move.l d1,a1
	IF MAK_FR=1
	jsr MAK_FREEf-R(A5)
	ELSE
MAK_FR:SET 1
	bsr.s MAK_FREEf
	bra.s MAK_FRs
MAK_FREEf:
	MAK_CALL exec,-210		;EFreeMem
	RTS
MAK_FRs:
	ENDC
MAK_FRskip\@:
	ENDM


MAK_AV:SET 0
MAK_AVAIL:MACRO			;Type (No "#" !!)[,#ResultVar]
	IF \1<128
	moveq #\1,d1
	ELSE
	move.l #\1,d1
	ENDC
	IF MAK_AV=1
	jsr MAK_AVAILf-R(A5)
	ELSE
MAK_AV:SET 1
	bsr.s MAK_AVAILf
	bra.s MAK_AVs
MAK_AVAILf:
	MOVE.L A6,-(SP)
	move.l 4.w,a6
	jsr -216(a6)			;AvailMem
	MOVE.L (SP)+,A6
	RTS
MAK_AVs:
	ENDC

	IFNB \2
	move.l d0,\2
	ENDC
	ENDM				;D0=AvailMem


MAK_NH:SET 0
MAK_NUMHEX:MACRO			;#ValueLong,#DestAddr
	IFNC \1,d0
	move.l \1,d0
	ENDC
	IFNC \2,a1
	move.l \2,a1
	ENDC
	IF MAK_NH=1
	jsr MAK_NUMHEXf-R(A5)
	ELSE
MAK_NH:SET 1
	bsr.s MAK_NUMHEXf
	bra.s MAK_NHs
MAK_NUMHEXf:
	MOVE.L D4,-(SP)
	moveq #"$",d4			;const
	moveq #-1,d3			;1st-flag
	moveq #7,d1
._NH1:	rol.l #4,d0
	moveq #15,d2
	and.w d0,d2
	bne.s ._NH2
	cmp.w #1,d1			;at least 2 digits !!
	ble.s ._NH2			;if last 2 digit is 0, do it anyway!
	subq.w #1,d3			;instead of skip-bra!
._NH2:	addq.w #1,d3
	bgt.s ._NH3
	move.b d4,(a1)+			;feed initial $/zeroes
	moveq #"0",d4
	tst.w d3
	blt.s ._NH4
	addq.w #1,d3
	move.l a1,a0			;update first non0 char ptr
._NH3:	move.b MAK_HexTbl(PC,d2.w),(a1)+
._NH4:	dbf d1,._NH1
	clr.b (a1)
	MOVE.L (SP)+,D4
	RTS
MAK_HexTbl:dc.b "0123456789ABCDEF"
MAK_NHs:
	ENDC
	ENDM		;A0=ptr to first non0 char,a1=0-term-ptr,D0 INTACT!


MAK_ND:SET 0
MAK_NUMDEC:MACRO			;#ValueLong,#DestAddr
	IFNC \1,d0
	move.l \1,d0
	ENDC
	IFNC \2,a1
	move.l \2,a1
	ENDC
	IF MAK_ND=1
	jsr MAK_NUMDECf-R(A5)
	ELSE
MAK_ND:SET 1
	bsr.s MAK_NUMDECf
	bra.w MAK_NDs
MAK_NUMDECf:
	MOVEM.L D4-D6/A2,-(SP)		;d0=Value.L,a1=destaddr
	moveq #0,d3			;1st-non0-reg
	moveq #"0",d4			;constant
	moveq #9,d6			;constant
	lea MAK_DecTbl-R(a5),a2		;a1=temp.addr,1st-non0-ptr >>A0
	move.l a1,a0
	moveq #9-1,d5
._ND1:	move.l (a2)+,d1

	moveq #0,d2
.dl:
	sub.l d1,d0
	blo.s .ddone
	addq.b #1,d2
	cmp.b d6,d2
	blo.s .dl
	sub.l d1,d0
.ddone:
	add.b d4,d2
	move.b d2,(a1)+

	add.l d1,d0			;"restore" to above-0

	or.b d2,d3
	cmp.b d4,d3
	bne.s ._ND3
	move.l a1,a0
._ND3:	dbf d5,._ND1

	add.b d4,d0			;remainder=last digit
	move.b d0,(a1)+
	clr.b (a1)			;0-terminated!
	move.l a1,d0
	sub.l a0,d0
	MOVEM.L (SP)+,D4-D6/A2
	RTS				;a0=1st-non0-ptr,a1=0-term-ptr, d0=len

MAK_DecTbl:dc.l 10^9,10^8,10^7,10^6,10^5,10^4,10^3,100,10
MAK_NDs:
	ENDC
	ENDM				;A0=1st-non0-ptr,A1=0-term-ptr


MAK_DN:	SET 0
MAK_DECNUM:MACRO			;#SrcAddr[,#ResultVar]
	IFNC \1,a0
	move.l \1,a0
	ENDC
	IF MAK_DN=1
	jsr MAK_DECNUMf-R(A5)
	ELSE
MAK_DN:SET 1
	bsr.s MAK_DECNUMf
	bra.s MAK_DNs
MAK_DECNUMf:		;a0=src text, end with 10 or 0 ->d0=number (-1=err)
	move.l d4,-(SP)
	moveq #0,d0
	moveq #10,d2
	moveq #"0",d3
	move.l a0,d4			;MSD stop ptr
.scanl:					;scan for end of string
	move.b (a0),d1
	cmp.b #"9",d1
	bls.s .noerr
.err:
	moveq #-1,d0
	bra.s .done
.noerr:
	cmp.b (a0)+,d3
	ble.s .scanl
	tst.b d1
	beq.s .asciiz
	cmp.b #10,d1
	bne.s .err
.asciiz:
	lea -1(a0),a1

	cmp.l a1,d4
	bge.s .done

	move.b -(a1),d0			;LSD straight in
	sub.b d3,d0			;LSD done
.digitl:
	cmp.l a1,d4			;hit stop ptr?
	bge.s .done

	moveq #0,d1
	move.b -(a1),d1
	sub.b d3,d1
	beq.s .zero
.addl:
	add.l d2,d0
	subq.w #1,d1
	bne.s .addl
.zero:
	move.l d2,d1
	lsl.l #2,d2
	add.l d1,d2			;x5
	add.l d2,d2			;x2
	bra.s .digitl
.done:
	move.l (SP)+,d4
	tst.l d0
	RTS
MAK_DNs:
	ENDC

	IFNB \2
	move.l d0,\2
	ENDC
	ENDM				;d0=number


MAK_HN:	SET 0
MAK_HEXNUM:MACRO			;#SrcAddr[,#ResultVar]
	IFNC \1,a0
	move.l \1,a0
	ENDC
	IF MAK_HN=1
	jsr MAK_HEXNUMf-R(A5)
	ELSE
MAK_HN:SET 1
	bsr.s MAK_HEXNUMf
	bra.s MAK_HNs
MAK_HEXNUMf:		;a0=src text, end with 10 or 0 ->d0=number (-1=err)
	move.l d4,-(SP)
	cmp.b #"$",(a0)
	bne.s .noSkip
	addq.w #1,a0			;skip optional leading $
.noSkip:
	moveq #0,d0
	moveq #1,d2
	moveq #"0",d3
	move.l a0,d4			;MSD stop ptr
.scanl:					;scan for end of string
	move.b (a0),d1
	bclr #5,d1			;uppercase
	cmp.b #"F",d1
	bls.s .noerr
.err:
	moveq #-1,d0
	bra.s .done
.noerr:
	cmp.b (a0)+,d3
	ble.s .scanl
	tst.b d1
	beq.s .asciiz
	cmp.b #10,d1
	bne.s .err
.asciiz:
	lea -1(a0),a1

.digitl:
	cmp.l a1,d4			;hit stop ptr?
	bge.s .done

	moveq #0,d1
	move.b -(a1),d1
	sub.b d3,d1
	beq.s .zero
	cmp.b #9,d1
	bls.s .addl
	sub.b #"A"-":",d1
.addl:
	add.l d2,d0
	subq.w #1,d1
	bne.s .addl
.zero:
	lsl.l #4,d2
	bra.s .digitl
.done:
	move.l (SP)+,d4
	tst.l d0
	RTS
MAK_HNs:
	ENDC

	IFNB \2
	move.l d0,\2
	ENDC
	ENDM				;d0=number


MAK_SR:SET 0
MAK_SEARCH:MACRO			;#Start,#End,#StringAddr(0-term.)
	IFNC \1,a0
	move.l \1,a0			;PREFERABLY, USE A0 AS MAK_CALLREG!
	ENDC
	IFNC \2,d1
	move.l \2,d1			;STRING LEN = 2-32767!
	ENDC
	IFNC \3,a1
	move.l \3,a1
	ENDC
	IF MAK_SR=1
	jsr MAK_SEARCHf-R(A5)
	ELSE
MAK_SR:SET 1
	bsr.s MAK_SEARCHf
	bra.s MAK_SRs
MAK_SEARCHf:
	MOVEM.L D2-D4/A2-A4,-(SP)
	moveq #0,d0			;default found-string length
	move.l d1,a4
	move.b -(a4),d4
	move.b (a1)+,d2
	move.b d2,(a4)
._SRl:	cmp.b (a0)+,d2			;Loop
	bne.s ._SRl

	cmp.l a0,d1
	ble.s ._SRn			;searched all text

	move.l a0,a2
	move.l a1,a3
._SRi:	move.b (a3)+,d3
	beq.s ._SRf			;investigated til 0 = found!
	cmp.b (a2)+,d3
	beq.s ._SRi			;otherwise investigate til NE
	bra.s ._SRl			;if not found, continue search!
._SRf:	move.w a3,d0
	sub.w a1,d0			;stringlen
._SRn:	move.b d4,(a4)
	MOVEM.L (SP)+,D2-D4/A2-A4
	tst.w d0
	RTS
MAK_SRs:
	ENDC ;EQ=NOT FOUND, D0=strlen,A0=addr+1 (for cont. search),A1=ADDR
	ENDM			;YOU CAN USE BOTH D0.W AND D0.L
