#!/bin/bash

# -------------------------------------------------------------
# Copyright (c) 2010-2011,
# Antonio Toral, Dublin City University
# atoral@computing.dcu.ie
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to 
#
# The Free Software Foundation, Inc., 
# 59 Temple Place - Suite 330, 
# Boston, MA  02111-1307, USA.
# -------------------------------------------------------------
#
# ---------
# CHANGELOG
# 20110315 discard sentences longer than 40 tokens (GIZA takes very long time)
# 20110111 header
# 20101220 changed seconds to nanoseconds in temp dir name
# 20101117 created
# ---------



#run_single_giza($___GIZA_F2E,$___E,$___F,
#                     $___VCB_E,$___VCB_F,
#                     $___CORPUS_DIR."/$___F-$___E-int-train.snt");

#run_single_snt2cooc($dir,$e,$f,$vcb_e,$vcb_f,$train) if $___PARTS == 1;
#$SNT2COOC $vcb_e $vcb_f $train > $dir/$f-$e.cooc


#plain2snt.out nc.lw.en nc.lw.fr
#mkcls -c50 -n2 -pnc.lw.en -Vnc.lw.en.vcb.classes
#mkcls -c50 -n2 -pnc.lw.fr -Vnc.lw.fr.vcb.classes

#snt2cooc.out nc.lw.en.vcb nc.lw.fr.vcb nc.lw.en_nc.lw.fr.snt > giza.fr-en.cooc
#GIZA++ -CoocurrenceFile giza.fr-en.cooc -c nc.lw.en_nc.lw.fr.snt -m1 5 -m2 0 -m3 3 -m4 3 -model1dumpfrequency 1 -model4smoothfactor 0.4 -nodumps 1 -nsmooth 4 -o giza.fr-en -onlyaldumps 1 -p0 0.999 -s nc.lw.en.vcb -t nc.lw.fr.vcb

#snt2cooc.out nc.lw.fr.vcb nc.lw.en.vcb nc.lw.fr_nc.lw.en.snt > giza.en-fr.cooc
#GIZA++ -CoocurrenceFile giza.en-fr.cooc -c nc.lw.fr_nc.lw.en.snt -m1 5 -m2 0 -m3 3 -m4 3 -model1dumpfrequency 1 -model4smoothfactor 0.4 -nodumps 1 -nsmooth 4 -o giza.en-fr -onlyaldumps 1 -p0 0.999 -s nc.lw.fr.vcb -t nc.lw.en.vcb

#/home/atoral/local/moses/scripts-20100701-1531/training/symal/giza2bal.pl -d giza.fr-en.A3.final -i giza.en-fr.A3.final >fren.bal
#/home/atoral/local/moses/scripts-20100701-1531/training/symal/giza2bal.pl -d giza.en-fr.A3.final -i giza.fr-en.A3.final >enfr.bal
#cat fren.bal | /home/atoral/local/moses/scripts-20100701-1531/training/symal/symal -alignment="grow" -diagonal="yes" -final="yes" -both="yes" > fren.aligned.grow-diag-final-and
#cat enfr.bal | /home/atoral/local/moses/scripts-20100701-1531/training/symal/symal -alignment="grow" -diagonal="yes" -final="yes" -both="yes" > enfr.aligned.grow-diag-final-and

set -e #if any command fails -> exit
set -u #if any variable not set -> exit

WDIR="/tmp/gizapp_`date +%Y%m%d_%H%M%N`"
GIZAPP="GIZA++ -m1 5 -m2 0 -m3 3 -m4 3 -model1dumpfrequency 1 -model4smoothfactor 0.4 -nodumps 1 -nsmooth 4 -onlyaldumps 1 -p0 0.999"
MKCLS="mkcls"
PLAIN2SNT="plain2snt.out"
SNT2COOC="snt2cooc.out"

#GIZA2BAL="/home/atoral/local/moses/scripts-20100701-1531/training/symal/giza2bal.pl"
#SYMAL="/home/atoral/local/moses/scripts-20100701-1531/training/symal/symal -alignment=grow -diagonal=yes -final=yes -both=yes"
#FILTER_LONG_SENTS="/home/atoral/local/moses/scripts-20100701-1531/training/clean-corpus-n.perl"

GIZA2BAL="giza2bal.pl"
SYMAL="symal -alignment=grow -diagonal=yes -final=yes -both=yes"
FILTER_LONG_SENTS="clean-corpus-n.perl"

SC=""
TC=""
SL=""
TL=""
NI=2
NC=50

rm -fr $WDIR
mkdir -p $WDIR
#mkdir -p $WDIR/src
#mkdir -p $WDIR/train


while [ "${1+isset}" ]; do
  case "$1" in
    -sc|--source-corpus)
      SC=$2
      echo "sc = $SC" >&2
      shift 2
      ;;
    -tc|--target-corpus)
      TC=$2
      echo "tc = $TC" >&2
      shift 2
      ;;
    -sl|--source-lang)
      SL=$2
      echo "sl = $SL" >&2
      shift 2
      ;;
    -tl|--target-lang)
      TL=$2
      echo "tl = $TL" >&2
      shift 2
      ;;
    -ni|--num-iterations)
      NI=$2
      echo "ni = $NI" >&2
      shift 2
      ;;
    -nc|--num-classes)
      NC=$2
      echo "nc = $NC" >&2
      shift 2
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [ "$SC" == "" -o "$TC" == "" ] ; then
  echo "Error: source corpus or target corpus not defined" >&2
  exit 1
fi

#SL=${SC##*.}
#TL=${TC##*.}
#echo "sl = $SL"
#echo "tl = $TL"
#echo "sc = $SC"
#echo "tc = $TC"

if [ "$SL" == "" -o "$TL" == "" ] ; then
  echo "Error: source lang or target lang not defined" >&2
  exit 1
fi


cp "$SC" "$WDIR/f.$SL"
cp "$TC" "$WDIR/f.$TL"
#echo "$SC" > "$WDIR/f.$SL"
#echo "$TC" > "$WDIR/f.$TL"
#SC=f.$SL
#TC=f.$TL
cd $WDIR

#clean-corpus-n.perl work/corpus/news-commentary.tok fr en work/corpus/news-commentary.clean 1 40
$FILTER_LONG_SENTS f $SL $TL f_clean 1 40 > filter_long_sents.log 2>&1
SC=f_clean.$SL
TC=f_clean.$TL

#plain2snt.out nc.lw.en nc.lw.fr
$PLAIN2SNT $SC $TC > plain.$SL-$TL.log 2>&1
$PLAIN2SNT $TC $SC > plain.$TL-$SL.log 2>&1

#mkcls -c50 -n2 -pnc.lw.en -Vnc.lw.en.vcb.classes
$MKCLS "-c$NC" "-n$NI" "-p$SC" "-V$SC.vcb.classes" > mkcls.$SL-$TL.log 2>&1
$MKCLS "-c$NC" "-n$NI" "-p$TC" "-V$TC.vcb.classes" > mkcls.$TL-$SL.log 2>&1

#snt2cooc.out nc.lw.en.vcb nc.lw.fr.vcb nc.lw.en_nc.lw.fr.snt > giza.fr-en.cooc
#GIZA++ -CoocurrenceFile giza.fr-en.cooc -c nc.lw.en_nc.lw.fr.snt -m1 5 -m2 0 -m3 3 -m4 3 -model1dumpfrequency 1 -model4smoothfactor 0.4 -nodumps 1 -nsmooth 4 -o giza.fr-en -onlyaldumps 1 -p0 0.999 -s nc.lw.en.vcb -t nc.lw.fr.vcb

#echo $SNT2COOC "$SC.vcb" "$TC.vcb" "$SC_$TC.snt"
$SNT2COOC "$SC.vcb" "$TC.vcb" *"$TC.snt" > giza.$TL-$SL.cooc 2> giza.$TL-$SL.cooc.log
$SNT2COOC "$TC.vcb" "$SC.vcb" *"$SC.snt" > giza.$SL-$TL.cooc 2> giza.$SL-$TL.cooc.log

$GIZAPP -CoocurrenceFile giza.$TL-$SL.cooc -c *"$TC.snt" -s "$SC.vcb" -t "$TC.vcb" -o giza.$SL-$TL > giza.$SL-$TL.log 2>&1
$GIZAPP -CoocurrenceFile giza.$SL-$TL.cooc -c *"$SC.snt" -s "$TC.vcb" -t "$SC.vcb" -o giza.$TL-$SL > giza.$TL-$SL.log 2>&1

#/home/atoral/local/moses/scripts-20100701-1531/training/symal/giza2bal.pl -d giza.fr-en.A3.final -i giza.en-fr.A3.final >fren.bal
#cat fren.bal | /home/atoral/local/moses/scripts-20100701-1531/training/symal/symal -alignment="grow" -diagonal="yes" -final="yes" -both="yes" > fren.aligned.grow-diag-final-and
$GIZA2BAL -d giza.$TL-$SL.A3.final -i giza.$SL-$TL.A3.final > giza.$SL-$TL.bal
cat giza.$SL-$TL.bal | $SYMAL > $TL-$SL.aligned.grow-diag-final-and
$GIZA2BAL -d giza.$SL-$TL.A3.final -i giza.$TL-$SL.A3.final > giza.$TL-$SL.bal
cat giza.$TL-$SL.bal | $SYMAL > $SL-$TL.aligned.grow-diag-final-and

cat $SL-$TL.aligned.grow-diag-final-and


#COMMAND="$BKALG -testSources $WDIR/src -trainSources $WDIR/src -englishSuffix $SL -foreignSuffix $TL -iters $NI $NI"
#echo $COMMAND
#$COMMAND > "$WDIR/log"
#cat "$WDIR/out/training.align"

