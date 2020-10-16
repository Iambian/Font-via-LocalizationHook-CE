/*
 *--------------------------------------
 * Program Name: Font Pack Previewer
 * Author: hehe
 * License: do whatever
 * Description: A font pack previewer
 *--------------------------------------
*/

#define COLOR_DARKER (0<<6)
#define COLOR_DARK (1<<6)
#define COLOR_LIGHT (2<<6)
#define COLOR_LIGHTER (3<<6)

#define COLOR_RED (3<<4)
#define COLOR_MAROON (2<<4)
#define COLOR_LIME (3<<2)
#define COLOR_GREEN (2<<2)
#define COLOR_BLUE (3<<0)
#define COLOR_NAVY (2<<0)

#define COLOR_MAGENTA (COLOR_RED|COLOR_BLUE)
#define COLOR_PURPLE (COLOR_MAROON|COLOR_NAVY)
#define COLOR_YELLOW (COLOR_RED|COLOR_LIME)
#define COLOR_CYAN (COLOR_LIME|COLOR_BLUE)
#define COLOR_WHITE (COLOR_RED|COLOR_BLUE|COLOR_LIME)
#define COLOR_GRAY (COLOR_MAROON|COLOR_GREEN|COLOR_NAVY)
#define COLOR_DARKGRAY ((1<<4)|(1<<2)|(1<<0))
#define COLOR_BLACK 0

#define TRANSPARENT_COLOR (COLOR_LIGHTER|COLOR_MAGENTA)

#define DEFAULT_COLOR COLOR_GREEN

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

/* Put your function prototypes here */
uint8_t 	staticMenu(char **sarr,uint8_t numstrings);
void 		alert(char **sarr,uint8_t numstrings);

void		DrawLFontExample( void *data );	/*Externally defined */
void		DrawSFontExample( void *data );	/*Externally defined */

void 		fn_Setup_Palette(void);
uint8_t 	InitVarSearch( uint8_t vartype);
uint8_t 	VarSearchNext(void);
uint8_t 	VarSearchPrev(void);
void*		GetFontStruct(void);
kb_key_t 	GetKbd(void);
void		PrintOp1(void);
void		PrintOp4(void);
kb_key_t	GetKbd(void);
void		InstallHook(void);
uint8_t		UninstallHook(void);


/*	Controls:
	Left/right changes vartype between progs, appvars, groups 
	Up/Down Cycles through programs, but only if there's something to view
 
 */

/* Put all your globals here */
void *groupmain[257];
void *grouptemp[257];
unsigned int groupcurvar;
const uint8_t typelist[] = {0x06,0x15,0x17};
const char *typenames[] = {"PROTPROG","APPVAR","GROUP"};
const char controlchars[] = {18,29,30,31,0};
const char updown[] = {18,32,32,0};
const char leftright[] = {29,32,0};
const char *installmenu[] = {"Install this font?"," Yes "," No "};
const char *fontinstalled[] = {"The font has been installed!"};
const char *fontuninstalled[] = {"The font has been uninstalled!"};


void main(void) {
	uint8_t i;
	uint8_t vartype;
	uint8_t topfile_result;
	uint8_t groupfile_result;
	uint8_t dosmallfont;
	uint8_t typeindex;
	kb_key_t k;
	void *ptr;
      void *tempptr;
	
	gfx_Begin();
	fn_Setup_Palette();
	
	gfx_SetDrawBuffer();
	
	dosmallfont = 1;
	vartype = 0x06;
	topfile_result = InitVarSearch(vartype);
	groupfile_result = 0xFF;
	typeindex = 0;
	
	k = kb_Yequ;	/* Key used to toggle lFont/sFont. Here, just priming screen */
	while (k!=kb_Mode) {
		if (k) {
			/* Perform keyboard checking here */
			if (k&kb_Yequ)		dosmallfont = !dosmallfont;
			if (k&kb_Left)		VarSearchPrev();
			if (k&kb_Right)		VarSearchNext();
			if (k&kb_Up && typeindex>0)		--typeindex;
			if (k&kb_Down && typeindex<2)	++typeindex;
			if (k&(kb_Up|kb_Down)) {
				vartype = typelist[typeindex];
				topfile_result = InitVarSearch(vartype);
			}
			if (k&kb_2nd) {
				if (staticMenu(installmenu,3)==1) {
					InstallHook();
					alert(fontinstalled,1);
				}
			}
			if (k&kb_Del) {
				if (!UninstallHook()) {
					alert(fontuninstalled,1);
				}
			}
			
			/* Perform lookup and graphics logic here */
			gfx_FillScreen(COLOR_BLUE|COLOR_LIGHTER|COLOR_MAROON|COLOR_LIME);
			gfx_SetColor(0);
			gfx_PrintStringXY("Font Previewing Program",80,4);
			gfx_HorizLine(0,14,320);
			gfx_PrintStringXY(updown,16,18);
			gfx_PrintString("Locating filetype: ");
			gfx_PrintString(typenames[typeindex]);
			gfx_SetTextXY(28,30);
			gfx_HorizLine(0,44,320);
			if (topfile_result) {
				gfx_PrintString("*** NO FONTS FOUND ***");
			} else {
				gfx_PrintString(leftright);
				PrintOp1();
				if (vartype==0x17) {
					gfx_PrintString(" :: ");
					PrintOp4();
				}
				ptr = GetFontStruct();
				if (ptr) {
					if (dosmallfont) {
						DrawSFontExample(ptr);
					} else {
						DrawLFontExample(ptr);
					}
				}
			}
			
			
			gfx_SwapDraw();
		}
		k = GetKbd();
	}
	gfx_End();
}

/* Put other functions here */


int getLongestLength(char **sarr, uint8_t numstrings);
void drawMenuStrings(char **sarr, uint8_t numstrings,int xbase, uint8_t ybase, int width, uint8_t height, uint8_t index, uint8_t cbase);
void menuRectangle(int x,uint8_t y,int w, uint8_t h, uint8_t basecolor);

void keywait() {
	while (!kb_AnyKey()); 
}

uint8_t staticMenu(char **sarr,uint8_t numstrings) {
	kb_key_t k;
	uint8_t oldtextcolor;
	int width,xbase,tempx,strwidth;
	uint8_t i,height,ybase,cbase,index,tempy;
	
	width = getLongestLength(sarr,numstrings)+8;
	height = (4+(numstrings-1)*12+16); //Border 4px, header 16px, others 10px
	xbase = (LCD_WIDTH-width)/2;
	ybase = (LCD_HEIGHT-height)/2;
	cbase = 0x19; //A faded green, set to darkest.
	index = 1;
	k = kb_Yequ;
	
	keywait();
	while (1) {
		k = GetKbd();
		
		if (k&kb_Mode) { index = 0; break;}
		if (k&kb_2nd) break;
		if ((k&kb_Up) && (!--index)) index = numstrings-1;
		if ((k&kb_Down) && (++index == numstrings)) index = 1;
		
		drawMenuStrings(sarr,numstrings,xbase,ybase,width,height,index,cbase);
		//Copy results to screen
		gfx_BlitRectangle(gfx_buffer,xbase,ybase,width,height);
	}
	gfx_SetTextFGColor(0);
	return index;
}


//We don't have newlines so we've got to do it via array of strings.
//sarr is structured exactly like menus, except there are no decisions
//and any key pressed will close the notice
void alert(char **sarr,uint8_t numstrings) {
	kb_key_t k;
	int width,xbase,tempx,strwidth;
	uint8_t i,height,ybase,cbase,index,tempy;
	
	width = getLongestLength(sarr,numstrings)+8;
	height = (4+(numstrings-1)*12+16); //Border 4px, header 16px, others 10px
	xbase = (LCD_WIDTH-width)/2;
	ybase = (LCD_HEIGHT-height)/2;
	cbase = 0x25; //A faded red, set to darkest.
	cbase = 0x19; //A faded green, set to darkest.
//	cbase = (2<<4) | (2<<2);  //Dark yellow?
	
	keywait();
	do {
		k = GetKbd();
		drawMenuStrings(sarr,numstrings,xbase,ybase,width,height,0,cbase);
		//Copy results to screen
		gfx_BlitRectangle(gfx_buffer,xbase,ybase,width,height);
	} while (!k);
	gfx_SetTextFGColor(0);
}

void drawMenuStrings(char **sarr, uint8_t numstrings,int xbase, uint8_t ybase, int width, uint8_t height, uint8_t index, uint8_t cbase) {
	uint8_t i,ytemp;
	int xtemp;
	
	//Draw the menubox
	menuRectangle(xbase,ybase,width,height,cbase);
	//Draw header area
	gfx_SetColor(cbase|COLOR_LIGHTER);
	gfx_HorizLine(xbase+6,ybase+15,width-12);
	gfx_SetTextFGColor(0x3C|COLOR_LIGHT);    //Picked using color contrast tool
	gfx_PrintStringXY(sarr[0],xbase+4,ybase+5);  //Header
	//Draw menu options
	xtemp = xbase+2;
	ytemp = ybase+18;
	gfx_SetTextFGColor(COLOR_WHITE|COLOR_LIGHT);
	gfx_SetColor(cbase|COLOR_DARK);
	for (i=1;i<numstrings;i++) {
		if (i==index) gfx_FillRectangle_NoClip(xtemp,ytemp,width-4,10);
		gfx_PrintStringXY(sarr[i],xtemp+(width-gfx_GetStringWidth(sarr[i]))/2-2,ytemp+1);
		ytemp += 12;
	}
}

int getLongestLength(char **sarr, uint8_t numstrings) {
	int largest_width,current_width;
	largest_width = 0;
	do {
		--numstrings;
		if ((current_width = gfx_GetStringWidth(sarr[numstrings])) > largest_width)
			largest_width = current_width;
	} while (numstrings);
	return largest_width;
}

void menuRectangle(int x,uint8_t y,int w, uint8_t h, uint8_t basecolor) {
	gfx_SetColor(basecolor|COLOR_LIGHTER);
	gfx_Rectangle_NoClip(x,y,w,h);
	gfx_SetColor(basecolor|COLOR_DARK);
	gfx_Rectangle_NoClip(++x,++y,w-=2,h-=2);
	gfx_SetColor(((basecolor>>1)&0x15)|COLOR_DARK); //darkshift, lighter
	gfx_FillRectangle(++x,++y,w-=2,h-=2);
}

























