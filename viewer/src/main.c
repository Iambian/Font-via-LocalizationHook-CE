/*
 *--------------------------------------
 * Program Name: Font Pack Previewer
 * Author: Iambian
 * License: MIT License
 * Description: A font pack previewer
 *--------------------------------------
*/

// Instructions image:
// "L/R: CHNGFONT | U/D: CHNGTYPE | DEL: (UN)INSTALL | MODE: EXIT | Y=: CHNGSIZE | 2ND: CHNGTXT"
/* Controls:
	Left/Right: Change font
	Up/Down: Change variable type (Program/Appvar/ProgramsInGroup/AppvarsInGroup)
	Delete: Install/Uninstall font pack
	2ND: Change text to display (ABC/Test Sentences)
	Y=: Change font size (Large/Small)
	Mode: Exit
*/

/* Keep these headers */
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <tice.h>

/* Standard headers (recommended) */
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* External library headers */
#include <debug.h>
#include <keypadc.h>
#include <graphx.h>
#include <fileioc.h>
#include <compression.h>

/* Add any other headers here */
#include "extern.h"


/* Put your function prototypes here */
void drawBuffer(void);
void updateState(void);
kb_key_t keyRead(void);
void printName(uint8_t *nameptr);

/* Put all your globals here */

#define LEN(x) (sizeof(x)/sizeof(x[0]))
#define SCREEN_TOP 4
#define LINE_HEIGHT 10
#define STATUS_COLSTART 8
#define DETAILS_COLSTART 128

#define COLOR_BACKGROUND 0xBE
#define COLOR_TEXT 0x00
#define COLOR_GREENTEXT 0x26
#define COLOR_REDTEXT 0xE0

state_t appstate = {
	.installed = false,
	.vartypeidx = 0,
	.fonttype = 0,
	.textdisptype = true,
	.varindex = 0,
	.maxvars = 0
};

fontvar_t fontvars;

uint8_t filetypes[] = { 0x06, 0x15, 0x17, 0x17};
uint8_t varindexbyfiletype[4];

/* -------------------------------------------------------------------------- */
int main(void) {

	kb_key_t k=0;
	bool statechanged;
	//uint8_t vartype;

	gfx_Begin();
	
	gfx_SetDrawBuffer();
	
	// Initial gather of files to populate the font count and other details before initial draw
	gatherFiles(appstate.vartypeidx, &fontvars);
	updateState();
	statechanged = true;	//Force initial draw
	k = kb_2nd;		//Primes key variable for initial display and to help force initial draw without needing to press a button
	do {
		if (k) {
			while (keyRead());	//Wait for all keys to be released before allowing another input to prevent multiple inputs from a single key press

			/* Perform keyboard checking here */
			if (k & kb_2nd) {
				appstate.textdisptype = !appstate.textdisptype;
				statechanged = true;
			}

			if (k & kb_Up) {
				if (appstate.vartypeidx > 0) {
					varindexbyfiletype[appstate.vartypeidx] = appstate.varindex;	//Save current index for this variable type before changing
					appstate.vartypeidx--;
					//vartype = filetypes[appstate.vartypeidx];
					gatherFiles(appstate.vartypeidx, &fontvars);
					updateState();
					statechanged = true;
				}
			}

			if (k & kb_Down) {
				if (appstate.vartypeidx < (LEN(filetypes)-1)) {
					varindexbyfiletype[appstate.vartypeidx] = appstate.varindex;	//Save current index for this variable type before changing
					appstate.vartypeidx++;
					//vartype = filetypes[appstate.vartypeidx];
					gatherFiles(appstate.vartypeidx, &fontvars);
					updateState();
					statechanged = true;
				}
			}

			if (k & kb_Left) {
				if (appstate.varindex > 0) {
					appstate.varindex--;
					statechanged = true;
				}
			}

			if (k & kb_Right) {
				if (appstate.varindex < (appstate.maxvars-1)) {
					appstate.varindex++;
					statechanged = true;
				}
			}

			/* Draw screen if state changed */
			if (statechanged) {
				drawBuffer();
				gfx_SwapDraw();
				statechanged = false;
			}
		}
		k = keyRead();
	} while (k!=kb_Mode);
	gfx_End();
}

/* Put other functions here */

void drawBuffer(void) {
	uint8_t oldcolor;
	uint8_t i;
	// Clear screen and draw border line between status and render area
	gfx_FillScreen(COLOR_BACKGROUND);
	gfx_SetColor(COLOR_TEXT);
	gfx_HorizLine(0, SCREEN_TOP + (3*LINE_HEIGHT), 320);

	// Draw title and status box
	gfx_SetTextXY(STATUS_COLSTART,SCREEN_TOP + (0*LINE_HEIGHT));
	gfx_PrintString("* Font Viewer *");

	gfx_SetTextXY(STATUS_COLSTART,SCREEN_TOP + (2*LINE_HEIGHT));
	if (appstate.fonttype == 0) {
		gfx_PrintString("LGFONT");
	} else {
		gfx_PrintString("SMFONT");
	}
	gfx_SetTextXY(STATUS_COLSTART + 56,SCREEN_TOP + (2*LINE_HEIGHT));
	if (appstate.textdisptype) {
		gfx_PrintString("SNTNC");
	} else {
		gfx_PrintString("ALPHA");
	}

	// Draw variable details area
	gfx_SetTextXY(DETAILS_COLSTART, SCREEN_TOP + (1*LINE_HEIGHT));
	switch (appstate.vartypeidx) {
		case 0:
			gfx_PrintString("PRGM");
			break;
		case 1:
			gfx_PrintString("AVAR");
			break;
		case 2:
			gfx_PrintString("GRPP");
			break;
		case 3:
			gfx_PrintString("GRPV");
			break;
	}
	gfx_PrintString(": ");
	if (appstate.maxvars > 0) {
		i = appstate.varindex;
		if (appstate.vartypeidx & 2) {	//Group variable, print group name first
			printName((uint8_t*)fontvars.groupname[i]);
			gfx_PrintString(" :: ");
		}
		printName((uint8_t*)fontvars.varname[i]);

		// TODO: Print variable name here, once implemented
		gfx_SetTextXY(DETAILS_COLSTART, SCREEN_TOP + (2*LINE_HEIGHT));
		// TODO: Print something here. I don't know if I want to deal with 
		// reaching into the font hook for metadata.
		// NOTE: Slight out of order rendering to prevent a font count with no
		// fonts available while reusing the same splitting logic.
		gfx_SetTextXY(DETAILS_COLSTART, SCREEN_TOP + (0*LINE_HEIGHT));
		gfx_PrintString("Fonts found: ");
		gfx_PrintUInt(appstate.varindex+1, 3);
		gfx_PrintChar('/');
		gfx_PrintUInt(appstate.maxvars, 3);
		gfx_SetTextXY(STATUS_COLSTART,SCREEN_TOP + (1*LINE_HEIGHT));
		if (appstate.installed) {
			oldcolor = gfx_SetTextFGColor(COLOR_GREENTEXT);
			gfx_PrintString("INSTALLED");
		} else {
			oldcolor = gfx_SetTextFGColor(COLOR_REDTEXT);
			gfx_PrintString("NOT INSTALLED");
		}
	} else {
		gfx_PrintString("** No fonts found **");
		gfx_SetTextXY(STATUS_COLSTART,SCREEN_TOP + (1*LINE_HEIGHT));
		oldcolor = gfx_SetTextFGColor(COLOR_REDTEXT);
		gfx_PrintString("NOT FOUND");
	}
	gfx_SetTextFGColor(oldcolor);

}

kb_key_t keyRead(void) {
	kb_key_t k;
	kb_Scan();
	k = kb_Data[7] | kb_Data[1];	//Merge groups: dpad & 2nd/mode/del/yequ
	return k;
}

void updateState(void) {
	// Updates state in response to change in variable type or index.
	appstate.varindex = varindexbyfiletype[appstate.vartypeidx];
	appstate.maxvars = fontvars.varcount;
}

void printName(uint8_t *nameptr) {
	uint8_t *s = nameptr;
	uint8_t nlen = *s;
	while (nlen) {
		s++;
		gfx_PrintChar(*s);
		nlen--;
	}
}