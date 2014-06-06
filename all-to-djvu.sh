#!/bin/sh

checkpackage()
{
	if ! type -p "$1" > /dev/null
	then
		echo "You need to install $2 package"
		exit
	fi
}

OPT() {
	printf "  %-20s %s\n" "$@"
}

help()
{
	echo "Usage: $0 [options] images..."
	echo
	echo "Options:"
	OPT "-c, --cover COVER" "Use COVER as a colored cover for the book"
	OPT "-p, --poster COVER" "Use COVER like a cover but posterize it"
	OPT "-b, --blur N" "Apply a blur filter of size N"
	OPT "-s, --sharp N" "Sharp filter strength (default 1)"
	OPT "-g, --gamma N" "Apply a gamma N"
	OPT "-l, --level N" "Apply a level N e.g. 10%,90%"
	OPT "-k, --keep" "Keep temporary files"
	OPT "-o, --out OUT" "File to write result"
	OPT "-r, --rotate N" "Rotate each image by N degrees"
	OPT "-L, --losslevel N" "Set lossy compression level to N (0-100)"
	OPT "-P, --PDF" "Export to PDF as well as to djvu"
	exit -1
}

get_dpi()
{
	size=$(identify "$1" | grep -o [0-9]*x[0-9]* | head -1 | cut -dx -f1)
	echo "$size/8.27" | bc
}

checkpackage djvm djvulibre
checkpackage c44 djvulibre
checkpackage convert ImageMagick

BLUR=""
GAMMA=""
LEVEL=""
AUTOLEVEL=""
COVER=""
CLEAN="1"
OUT=out.djvu
SHARP="1"
UP=""
DOWN=""
ROT=""
LOSSLVL=100
FILTER="-paint 1"
#convert -h | grep -- -auto-level > /dev/null && AUTOLEVEL="-auto-level"

BG="-background white"

N=1

while [ $# -gt 0 ]
do
	case "$1" in
-c|--cover)
	if [ ! -f "$2" ]
	then
		echo "Cannot find file: $2" > /dev/stderr
	else
		convert "$2" .cover.ppm
		c44 -dpi $(get_dpi "$2") .cover.ppm .cover.djvu
		COVER=".cover.djvu"
	fi
	shift
;;
-p|--poster)
	if [ ! -f "$2" ]
	then
		echo "Cannot find file: $2" > /dev/stderr
	else
		convert -unsharp 0x3+2 -posterize 2 "$2" .cover.ppm
		cpaldjvu -dpi $(get_dpi "$2") .cover.ppm .cover.djvu
		COVER=".cover.djvu"
	fi
	shift
;;
-b|--blur)
	BLUR="-blur $2"
	shift
;;
-g|--gamma)
	GAMMA="-gamma $2"
	shift
;;
-l|--level)
	LEVEL="-level $2"
	shift
;;
-k|--keep)
	CLEAN="0"
;;
-o|--out)
	OUT="$2"
	shift
;;
-s|--sharp)
	SHARP="$2"
	shift
;;
-u|--upscale)
	UP="-resize $2"
	shift
;;
-d|--downscale)
	DOWN="-resize $2"
	shift
;;
-r|--rotate)
	ROT="-rotate $2"
	shift
;;
-f|--filter)
	case "$2" in
	median)
		FILTER="-median 0x1"
	;;
	paint)
		FILTER="-paint 1"
	;;
	*)
		FILTER=""
	;;
	esac
	shift
;;
*)
UNROTATE=""
UNROTATE="-deskew 100%"

ENHANCE=" $BLUR $GAMMA -unsharp 0x10+$SHARP+0"
ENHANCE=" $BLUR $GAMMA -unsharp 0x5+$SHARP+0 ( +clone -blur 0x20 ) -compose Divide_Src -composite -normalize"

THRESHOLD=""
THRESHOLD="-monochrome"
THRESHOLD="-threshold 60%"

#FILTER="-statistic Mode 2x2"
#FILTER="-negate -median 2x2 -negate"
#FILTER=""
#FILTER="-paint 1"


OPTS="$ROT $UNROTATE $LEVEL $AUTOLEVEL $UP $ENHANCE $DOWN $THRESHOLD $FILTER"
	if [ ! -f "$1" ]
	then
		echo "Cannot find file: $1" > /dev/stderr
	else
		NAME=$(printf "%06d" $N)
		convert "$1" $OPTS .$NAME.pbm
		#echo PSNR: $(compare -metric PSNR $1 .tmp.pbm /dev/null 2>&1)
		cjb2 -dpi $(get_dpi ".$NAME.pbm") -lossy -losslevel $LOSSLVL .$NAME.pbm .$NAME.djvu
		
		echo "$1" $(wc -c < .$NAME.djvu) "bytes"
		((N++))
	fi
;;
	esac
	shift
done
if [ -z "$COVER" ]
then 
	djvm -c "$OUT" .0*.djvu
else
	djvm -c "$OUT" "$COVER" .0*.djvu
fi

#convert -compress Group4 .*.pbm out.pdf

if [ "$CLEAN" = "1" ]
then
	rm -f .*.pbm
	rm -f .*.ppm
	rm -f .*.djvu
fi
