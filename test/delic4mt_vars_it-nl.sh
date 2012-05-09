#!/bin/bash

LP="it-nl"
SL="it"
TL="nl"

#names of systems and checkpoints
declare -a SYSTEMS=("bing.$LP.$TL" "cosyne_baseline.$LP.$TL" "google.$LP.$TL" "systran.$LP.$TL")
declare -a CHECKPS=("a_$SL" "n_$SL" "r_$SL" "v_$SL" "prep_$SL" "pronoun_$SL" "pos_seq_3gram_$SL" "pos_seq_4gram_$SL" "n_di_n_$SL" "polysemous_$SL")

#output dir
WORK_DIR="/home/atoral/Documents/cosyne/wp5/WP52/checkpoints/eval_y2/eval-$SL-$TL"

#data
TEST_SL="/home/atoral/Documents/cosyne/wp5/WP52/towards_D52_M24/test_data/$SL.test.kaf"
TEST_TL="/home/atoral/Documents/cosyne/wp5/WP52/towards_D52_M24/test_data/$TL.test.kaf"
TEST_ALG="/home/atoral/Documents/cosyne/wp5/WP52/towards_D52_M24/test_data/$SL-$TL.alignment"
PROFILE_DIR="/home/atoral/Documents/cosyne/wp5/WP52/towards_D52_M24/kybot_profiles"
SYSTEMS_DIR="/home/atoral/Documents/cosyne/wp5/WP52/towards_D52_M24/evaluation"

#software
KYBOT_DIR="/home/atoral/soft/svn/kyoto/trunk/modules/mining_module"
DELIC4MT_DIR="/home/atoral/Documents/cosyne/wp5/WP52/delic4mt_120207"


