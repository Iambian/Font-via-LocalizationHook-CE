/*
 *--------------------------------------
 * Program Name: Font Pack Previewer
 * Author: hehe
 * License: do whatever
 * Description: A font pack previewer
 *--------------------------------------
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

/* Put your function prototypes here */


void DrawLFontExample( void *data );	/*Externally defined */
void DrawSFontExample( void *data );	/*Externally defined */




/* Put all your globals here */

void main(void) {
	uint8_t i;
	
	gfx_Begin();
	
	
	DrawLFontExample(NULL);		/* Test. DO NOT ACTUALLY RUN */
	DrawSFontExample(NULL);		/* Test. DO NOT ACTUALLY RUN */
	
	
	gfx_End();
}

/* Put other functions here */

