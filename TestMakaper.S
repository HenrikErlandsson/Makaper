

	*===============================================.
	;						|
	* 		Makaper "Unit" Test		(
	;						|
	*-----------------------------------------------+
	; by Photon of Scoopex © 2025 Henrik Erlandsson	|
	*=========#=====================================#
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

;Note: Every macro is tested twice to test every line of code in the include.
;This means all you need can be built by cut/paste of lines from this source.

MAK_Libs	=%111111	;Expansion,MathFFP,Layers,Gfx,Intuition,Dos
MAK_MaxParams	=8
MAK_TxtBufSize	=80

	INCLUDE "Makaper.S"
B:
R	=B+32768

    *--- Typical startup ---*

	MAK_INIT
	MAK_FAKEPARAM "test.txt"
	MAK_GETPARAMS a0,#8
	MAK_OPENLIBS
	beq.w CRIT			;No libs!
	MAK_IO
;	beq.s EXIT			;no OutHdl (0 = > NIL: so OK)

    *--- Read a file ---*

	lea FileBuf(PC),a2
	MAK_OPENF FileHdl-R(A5),MAK_Params(PC),#1005	;_Old
	beq.w Skip
	MAK_READF FileHdl-R(A5),a2,#FileBufE-FileBuf
	clr.b (a2,d0.w)				;Make this AsciiZ

	MAK_WRITE "Test"
	MAK_WRITE "Test"
	MAK_WRITELN "File Contents:"
	MAK_WRITEA a2
	MAK_WRITELNA a2

FileError:
	MAK_CLOSEF FileHdl-R(A5)
Skip:

	lea FileBuf(PC),a2
	MAK_OPENF FileHdl-R(A5),MAK_Params(PC),#1005	;_Old
	beq.w Skip2
	MAK_READF FileHdl-R(A5),a2,#FileBufE-FileBuf
	clr.b (a2,d0.w)				;Make this AsciiZ

	MAK_WRITELN "File Contents:"
	MAK_WRITEA a2
	MAK_WRITELNA a2

FileError2:
	MAK_CLOSEF FileHdl-R(A5)
Skip2:

    *--- Load file ---*

	MAK_LOADF #FileName,0
	bmi.w AllocErr
	beq.w FileErr
	movem.l d0/a0,FileLen-R(A5)

	MAK_NUMDEC d0,#MAK_TxtBuf
	MAK_WRITELNA a0
	MAK_DECNUM #MAK_TxtBuf

	MAK_NUMHEX #$13a,#MAK_TxtBuf
	MAK_WRITELNA #MAK_TxtBuf		;include $ and zeroes
	MAK_HEXNUM #MAK_TxtBuf
	
FileErr:
	movem.l FileLen-R(A5),d0/a0
	MAK_FREE a0,d0
AllocErr:

	MAK_LOADF #FileName,0
	bmi.w AllocErr2
	beq.w FileErr2
	movem.l d0/a0,FileLen-R(A5)

	MAK_NUMDEC d0,#MAK_TxtBuf
	MAK_WRITELNA a0
	MAK_DECNUM #MAK_TxtBuf
	
	MAK_NUMHEX #$1337BABE,#MAK_TxtBuf
	MAK_WRITELNA a0
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

	MAK_ALLOC #1024,0
	move.l d0,AllocP-R(A5)
	MAK_FREE AllocP-R(A5),#1024
	clr.l AllocP-R(A5)

	MAK_ALLOC #1024,0
	move.l d0,AllocP-R(A5)
	MAK_FREE AllocP-R(A5),#1024
	clr.l AllocP-R(A5)

	MAK_AVAIL 0				;_Any
	MAK_AVAIL $20002			;_Largest+_Chip

	MAK_SEARCH #FileName,#FileNameE,#SearchStr
	MAK_SEARCH #FileName,#FileNameE,#FileName

DONE:
	MAK_CLOSELIBS
CRIT:
EXIT:
	RTS	

    *--- Strings ---*

MyFake:
	dc.b "test.txt",0

FileName:
	dc.b "test.txt",0
FileNameE:

SearchStr:
	dc.b ".txt",0

    *--- Vars ---*

	EVEN
AllocP:	dc.l 0
FileHdl:dc.l 0
FileLen:dc.l 0
FileAddr:dc.l 0
FileLock:dc.l 0

    *--- Buffers ---*

	CNOP 0,4				;required
FileBuf:
	dcb.b 80,0
FileBufE:
	dc.b 0				;ensure ASCIIZ if printed or COPYS'd

	CNOP 0,4
FileInfo:
	dcb.l 260/4,0

