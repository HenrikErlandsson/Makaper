

	*===============================================.
	;						|
	; 		Makaper "Unit" Test		(
	;						|
	*-----------------------------------------------+
	; by Photon of Scoopex © 2025 Henrik Erlandsson	|
	*=========#=====================================#
	; 1.5	  | Test optional resultVars		|
	; 1.4	  | Handle missing test.txt, flow fixes	|
	; 1.3	  | Dynamic INIT,OPENLIBS,CALL+MAK_move	|
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

;All you need can be built by cut/paste of chunks from this source.

;Constants in this source are only needed by the test, not by Makaper.
;If you write a program from scratch, you must declare global label R,
;and between MAK_INIT and MAK_CLOSELIBS preserve the address to it in a5.

MaxParams	=1
TxtBufSize	=80
EAvailMem	=-216

	INCLUDE "Makaper.S"
R:

    *--- Typical startup ---*

	MAK_INIT TxtBufSize,"Usage: Copy test.txt to exe folder."
	MAK_FAKEPARAM "nonsense"
	MAK_GETPARAMS a0,MaxParams
	beq.w CRIT

	MAK_OPENLIBS dos
	beq.w DONE			;demo 0-ptr tolerance
	MAK_IO
;	beq.s EXIT			;no OutHdl (0 = > NIL: so OK)

	MAK_WRITE "** Starting tests..."
	MAK_WRITEF MAK_outHdl-R(A5),#LineFeed,#1
	MAK_WRITEF MAK_outHdl-R(A5),#LineFeed,#1,ResultVar

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
	beq.w Skip2
	MAK_READF FileHdl-R(A5),a2,#FileBufE-FileBuf,ResultVar
	beq.s FileError2
	clr.b (a2,d0.w)			;Make this ASCIIZ

	MAK_WRITE "File Contents x 2: ",ResultVar
	MAK_WRITEA a2,ResultVar
	MAK_WRITELNA a2,ResultVar

FileError2:
	MAK_CLOSEF FileHdl-R(A5)
Skip2:

	MAK_OPENF FileHdl-R(A5),#FileName,#1005	;_Old
	beq.w Skip3
	MAK_READLN FileHdl-R(A5)
	MAK_CLOSEF FileHdl-R(A5)
Skip3:
	MAK_OPENF FileHdl-R(A5),#FileName,#1005	;_Old
	beq.w Skip4
	MAK_READLN FileHdl-R(A5)
	MAK_CLOSEF FileHdl-R(A5)
Skip4:


    *--- Load file ---*

	MAK_LOADF #FileName,0			;_Any
	bmi.w AllocErr
	movem.l d0/a0,FileLen-R(A5)
	bne.s FileOk
	MAK_WRITELN "test.txt not found in current folder"
FileOk:
	movem.l FileLen-R(A5),d0/a0
	MAK_FREE a0,d0
AllocErr:

	MAK_LOADF #FileName,0			;_Any
	bmi.w AllocErr2
	movem.l d0/a0,FileLen-R(A5)
	bne.s FileOk2
	MAK_WRITELN "test.txt not found in current folder",ResultVar
FileOk2:
	movem.l FileLen-R(A5),d0/a0
	MAK_FREE a0,d0
AllocErr2:

    *--- Number conversion ---*

	MAK_NUMDEC #14,#MAK_TxtBuf
	MAK_WRITELNA a0
	MAK_DECNUM #MAK_TxtBuf

	MAK_NUMHEX #$13a,#MAK_TxtBuf
	MAK_WRITELNA #MAK_TxtBuf		;demo including $ and zeroes
	MAK_HEXNUM #MAK_TxtBuf

	MAK_NUMDEC #-1,#MAK_TxtBuf
	MAK_WRITELNA a0				;demo largest integer conv
	MAK_DECNUM #MAK_TxtBuf,ResultVar

	MAK_NUMHEX #13,#MAK_TxtBuf
	MAK_WRITELNA a0				;demo min. 2 digits feature
	MAK_HEXNUM #MAK_TxtBuf,ResultVar

    *--- Examine file ---*

Lock1:
	MAK_LOCK #FileName,#-2			;_AccR
	move.l d0,FileLock-R(A5)
	beq.s LockErr1
	
	lea FileInfo-R(A5),a2
	MAK_EXAMINE FileLock-R(A5),a2

	lea 8(a2),a0
	lea MAK_TxtBuf-R(A5),a1
	clr.b TxtBufSize-1(a0)			;ensure fits in buf
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
	clr.b TxtBufSize-1(a0)			;ensure fits in buf
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

	MAK_ALLOC #1024,0,ResultVar		;_Any
	move.l d0,AllocP-R(A5)
	beq.s AllocErr4
	MAK_WRITELN "Alloc 1K OK."
AllocErr4:			;label moved here to demo 0-ptr tolerance
	MAK_FREE AllocP-R(A5),#1024
	clr.l AllocP-R(A5)

	MAK_AVAIL 0				;_Any
	MAK_AVAIL $20002,ResultVar		;_Largest+_Chip

    *--- equivalents of above using MAK_move, MAK_CALL ---*
	MAK_move.w #0,d1
	MAK_CALL exec,EAvailMem			;don't store result
MoveCallTest:
	moveq #2,d1
	MAK_move.w #0,d1,#1,d2,#3,d7,#4,a0	;full test again
	MAK_CALL exec,EAvailMem			;don't store result

	MAK_move.l #$20002,d1
	MAK_CALL exec,EAvailMem,FileLen-R(A5)

	MAK_move.l #$20002,d1,#1,d2,#3,d7,#4,a0	;full test again
	MAK_CALL exec,EAvailMem,FileLen-R(A5)

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
LineFeed:
	dc.b 10

    *--- Vars ---*

	EVEN
AllocP:	dc.l 0
FileHdl:dc.l 0
FileLen:dc.l 0
FileAddr:dc.l 0				;must follow FileLen
FileLock:dc.l 0
ResultVar:dc.l 0

    *--- Buffers ---*

	CNOP 0,4			;required
FileBuf:
	dcb.b 80,0
FileBufE:
	dc.b 0				;ensure ASCIIZ if printed or COPYS'd

	CNOP 0,4
FileInfo:
	dcb.l 260/4,0

