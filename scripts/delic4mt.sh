#!/bin/bash

# script that automates the different steps of DELiC4MT
#
# Copyright (c) 2011-12,
# Antonio Toral, Dublin City University
# atoral@computing.dcu.ie
#
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
#
#
# -------------------------------------------------------------
#
# ---------
# CHANGELOG
# 20120515 add support for filtering checkpoints
# 20111215 some improvements
# 20110822 created
# ---------
#

set -e #if any command fails -> exit
set -u #if any variable not set -> exit


usage(){
	echo "Usage: $0 file_with_variables"
	exit 1
}


# given two outputs of linguistic checkpoints evaluation returns true if the first has higher score
a_higher_than_b() {
	SYSTEMA=$1
	SYSTEMB=$2

	SCOREA=`tail -n 1 $SYSTEMA | awk '{print $NF}'`
	SCOREB=`tail -n 1 $SYSTEMB | awk '{print $NF}'`

	result=`expr $SCOREA \> $SCOREB`
	if [ "$result" -eq "1" ]; then
		echo "      delic4mt::a_higher_than_b scorea $SCOREA > scoreb $SCOREB -> return true" 1>&2
		return 0
	fi
	echo "      delic4mt::a_higher_than_b scorea $SCOREA < scoreb $SCOREB -> return false" 1>&2
	return 1
}


[[ $# -eq 0 ]] && usage
source "$1"

ORIG_DIR=`pwd`

rm -fr $WORK_DIR/
mkdir -p $WORK_DIR
mkdir -p $WORK_DIR/data

echo "delic4mt::main evaluating ${#SYSTEMS[@]} systems on ${#CHECKPS[@]} checkpoints" 1>&2

echo "delic4mt::main loading kybots and test sets" 1>&2
cd $KYBOT_DIR
./doc_load.pl --container-name script_docs-$LP-$SL --force $TEST_SL
./doc_load.pl --container-name script_docs-$LP-$TL --force $TEST_TL
./kybot_load.pl --container-name script_kybots-$SL --force $PROFILE_DIR/*_$SL.xml


for CHECKP in ${CHECKPS[@]} ; do
	echo "delic4mt::main processing checkpoint $CHECKP" 1>&2
	echo "  delic4mt::main running kybot" 1>&2
	cd $KYBOT_DIR
	./kybot_run.pl --dry-run --profile-from-db --container-name script_docs-$LP-$SL --kybot-container-name script_kybots-$SL kybot_$CHECKP.xml > $WORK_DIR/out_$CHECKP.xml


	if [ -n "$CONSTRAINTS" ]; then
		echo "  delic4mt::main filtering checkpoint" 1>&2
		mv $WORK_DIR/out_$CHECKP.xml $WORK_DIR/out_$CHECKP.unfiltered.xml
		perl $DELIC4MT_DIR/scripts/filter_checkpoints.pl -kybot_out $WORK_DIR/out_$CHECKP.unfiltered.xml -alignment $TEST_ALG -kaf_tl $TEST_TL -constraints $CONSTRAINTS > $WORK_DIR/out_$CHECKP.xml 2> $WORK_DIR/out_$CHECKP.filter.log
	fi


	echo "  delic4mt::main evaluating MT systems" 1>&2
	cd $WORK_DIR
	for SYSTEM in ${SYSTEMS[@]} ; do
		java -jar $DELIC4MT_DIR/evaluate/delic4mt.jar -alg $TEST_ALG -sl_kaf $TEST_SL -tl_kaf $TEST_TL -lc $WORK_DIR/out_$CHECKP.xml -run $SYSTEMS_DIR/$SYSTEM > $WORK_DIR/$SYSTEM-$CHECKP.out

	done


	echo "  delic4mt::main running statistical significance tests" 1>&2
	for SYSTEMA in ${SYSTEMS[@]} ; do
		for SYSTEMB in ${SYSTEMS[@]} ; do
			if [ $SYSTEMA != $SYSTEMB ] ; then
				echo "    delic4mt::main $SYSTEMA and $SYSTEMB"
				if ( a_higher_than_b "$WORK_DIR/$SYSTEMA-$CHECKP.out" "$WORK_DIR/$SYSTEMB-$CHECKP.out" ) ; then
					perl $DELIC4MT_DIR/scripts/lingcheckp_sig.pl $WORK_DIR/$SYSTEMA-$CHECKP.out $WORK_DIR/$SYSTEMB-$CHECKP.out >> $WORK_DIR/stat_sig-$LP 2>&1
				fi

			fi
		done
	done
done


# cleanup
rm -fr $KYBOT_DIR/dbxml/script_docs* $KYBOT_DIR/dbxml/script_kybots*
rm -fr $WORK_DIR/data
cd $ORIG_DIR

exit 0

