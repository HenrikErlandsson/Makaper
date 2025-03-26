

	*===============================================.
	;						|
	* 		Makaper "Unit" Test		(
	;						|
	*-----------------------------------------------+
	; by Photon of Scoopex © 2025 Henrik Erlandsson	|
	*=========#=====================================#
	; 1.2	  | Cleanup, better & more tests	|
	; 1.1	  | Initial release			|
	; 0.8	  | Adding avail, alloc, free, search	|
	; 0.7	  | Adding lock, examine, unlock	|
	; 0.6	  | Refactoring include part 2		|
	; 0.5	  | Refactoring include			|
	; 0.4	  | Tested remaining macros		|
	; 0.3	  | Test remaining macros		|
	; 0.2	  | Removed dependencies, added MAK_IO	|
	; 0.1	  | Include all functions twice.	|
	*---------+-------------------------------------*
	; Notes: /
	*-------*

;Note: Every (non-init/exit) macro is tested twice to test every line of code 
;in the include.

;This means all you need can be built by cut/paste of lines from this source.

MAK_Libs	=%111111	;Expansion,MathFFP,Layers,Gfx,Intuition,Dos
MAK_MaxParams	=8
MAK_TxtBufSize	=80

	INCLUDE "Makaper.S"
R:

    *--- Typical startup ---*

	MAK_INIT
	MAK_FAKEPARAM "nonsense"
	MAK_GETPARAMS a0,#8
	beq.w CRIT

	MAK_OPENLIBS
	beq.w DONE			;demo 0-ptr tolerance
	MAK_IO
;	beq.s EXIT			;no OutHdl (0 = > NIL: so OK)

	MAK_WRITELN "** Starting tests..."
	MAK_WRITELN

    *--- Read a file ---*

	lea FileBuf-R(A5),a2
	MAK_OPENF FileHdl-R(A5),MAK_Params-R(A5),#1005	;_Old
	beq.w Skip			;nonsense fake param should skip
	MAK_READF FileHdl-R(A5),a2,#FileBufE-FileBuf
	beq.s FileError
	clr.b (a2,d0.w)			;Make this ASCIIZ

	MAK_WRITE "File Contents x 2: "
	MAK_WRITEA a2
	MAK_WRITELNA a2

FileError:
	MAK_CLOSEF FileHdl-R(A5)
Skip:

	lea FileBuf-R(A5),a2
	MAK_OPENF FileHdl-R(A5),#FileName,#1005	;_Old
	beq.w Skip
	MAK_READF FileHdl-R(A5),a2,#FileBufE-FileBuf
	beq.s FileError
	clr.b (a2,d0.w)			;Make this ASCIIZ

	MAK_WRITE "File Contents x 2: "
	MAK_WRITEA a2
	MAK_WRITELNA a2

FileError2:
	MAK_CLOSEF FileHdl-R(A5)
Skip2:

    *--- Load file ---*

	MAK_LOADF #FileName,0			;_Any
	bmi.w AllocErr
	beq.w FileErr
	movem.l d0/a0,FileLen-R(A5)

	MAK_NUMDEC d0,#MAK_TxtBuf
	MAK_WRITELNA a0
	MAK_DECNUM #MAK_TxtBuf

	MAK_NUMHEX #$13a,#MAK_TxtBuf
	MAK_WRITELNA #MAK_TxtBuf		;demo including $ and zeroes
	MAK_HEXNUM #MAK_TxtBuf

FileErr:
	movem.l FileLen-R(A5),d0/a0
	MAK_FREE a0,d0
AllocErr:

	MAK_LOADF #FileName,0			;_Any
	bmi.w AllocErr2
	beq.w FileErr2
	movem.l d0/a0,FileLen-R(A5)

	MAK_NUMDEC #-1,#MAK_TxtBuf
	MAK_WRITELNA a0				;demo largest integer conv
	MAK_DECNUM #MAK_TxtBuf

	MAK_NUMHEX #13,#MAK_TxtBuf
	MAK_WRITELNA a0				;demo min. 2 digits feature
	MAK_HEXNUM #MAK_TxtBuf

FileErr2:
	movem.l FileLen-R(A5),d0/a0
	MAK_FREE a0,d0
AllocErr2:

    *--- Examine file ---*

Lock1:
	MAK_LOCK #FileName,#-2			;_AccR
	move.l d0,FileLock-R(A5)
	beq.s LockErr1
	
	lea FileInfo-R(A5),a2
	MAK_EXAMINE FileLock-R(A5),a2

	lea 8(a2),a0
	lea MAK_TxtBuf-R(A5),a1
	clr.b MAK_TxtBufSize-1(a0)		;ensure fits in buf
	MAK_COPYS a0,a1
	MAK_WRITELNA #MAK_TxtBuf

	MAK_UNLOCK FileLock-R(A5)
	clr.l FileLock-R(A5)
LockErr1:

Lock2:
	MAK_LOCK #FileName,#-2			;_AccR
	move.l d0,FileLock-R(A5)
	beq.s LockErr2
	
	lea FileInfo-R(A5),a2
	MAK_EXAMINE FileLock-R(A5),a2

	lea 8(a2),a0
	lea MAK_TxtBuf-R(A5),a1
	clr.b MAK_TxtBufSize-1(a0)		;ensure fits in buf
	MAK_COPYS a0,a1
	MAK_WRITELNA #MAK_TxtBuf

	MAK_UNLOCK FileLock-R(A5)
	clr.l FileLock-R(A5)
LockErr2:

    *--- Test remaining macros ---*

	MAK_ALLOC #1024,0			;_Any
	move.l d0,AllocP-R(A5)
	beq.s AllocErr3
	MAK_WRITELN "Alloc 1K OK."
	MAK_FREE AllocP-R(A5),#1024
	clr.l AllocP-R(A5)
AllocErr3:

	MAK_ALLOC #1024,0			;_Any
	move.l d0,AllocP-R(A5)
	beq.s AllocErr4
	MAK_WRITELN "Alloc 1K OK."
AllocErr4:			;label moved here to demo 0-ptr tolerance
	MAK_FREE AllocP-R(A5),#1024
	clr.l AllocP-R(A5)

	MAK_AVAIL 0				;_Any
	MAK_AVAIL $20002			;_Largest+_Chip

	MAK_SEARCH #FileName,#FileNameE,#SearchStr
	beq.s NotFound1
	move.l d0,d7
	MAK_WRITE "String match with length: "
	MAK_NUMDEC d7,#MAK_TxtBuf
	MAK_WRITELNA #MAK_TxtBuf		;demo leading 0s
NotFound1:
	MAK_SEARCH #FileName,#FileNameE,#Nonsense
	bne.s Found1
	MAK_WRITELN "String not found, OK."
Found1:
	MAK_WRITELN "** Tests concluded."
DONE:
	MAK_CLOSELIBS
CRIT:
EXIT:
	RTS	

    *--- Strings ---*

Nonsense:
	dc.b "testtxt",0

FileName:
	dc.b "test.txt",0
FileNameE:

SearchStr:
	dc.b "t.tx",0

    *--- Vars ---*

	EVEN
AllocP:	dc.l 0
FileHdl:dc.l 0
FileLen:dc.l 0
FileAddr:dc.l 0				;must follow FileLen
FileLock:dc.l 0

    *--- Buffers ---*

	CNOP 0,4			;required
FileBuf:
	dcb.b 80,0
FileBufE:
	dc.b 0				;ensure ASCIIZ if printed or COPYS'd

	CNOP 0,4
FileInfo:
	dcb.l 260/4,0

