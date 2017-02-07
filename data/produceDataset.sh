#!/bin/bash
set -ex
set -o pipefail

cooccurrenceDir=$1
occurrenceDir=$2
sentenceCountDir=$3

splitYear=$4
outDir=$5

mkdir -p $outDir

cooccurrenceDir=`readlink -f $cooccurrenceDir`
occurrenceDir=`readlink -f $occurrenceDir`
sentenceCountDir=`readlink -f $sentenceCountDir`
outDir=`readlink -f $outDir`

tmpDir=tmp

trainingAndValidationSplit=$splitYear
trainingSplit=$(($splitYear-1))

testSize=1000000
validationSize=$testSize

###########################
# Training and Validation #
###########################

mkdir -p $tmpDir/trainingAndValidation/cooccurrences
mkdir -p $tmpDir/trainingAndValidation/occurrences
mkdir -p $tmpDir/trainingAndValidation/sentenceCounts

find $cooccurrenceDir -type f | xargs -I FILE basename FILE | cut -f 1 -d '.' | sort -n -u | awk -v splitYear=$trainingAndValidationSplit ' { if ( $1<=splitYear) print; } ' > $tmpDir/trainingAndValidation.years
find $cooccurrenceDir -type f | xargs -I FILE basename FILE | cut -f 1 -d '.' | sort -n -u | awk -v splitYear=$trainingAndValidationSplit ' { if ( $1>splitYear) print; } ' > $tmpDir/test.years

cat $tmpDir/trainingAndValidation.years | xargs -I YEAR echo "find $cooccurrenceDir -type f -name 'YEAR*'" | sh > $tmpDir/trainingAndValidationFiles.cooccurrences
cat $tmpDir/trainingAndValidation.years | xargs -I YEAR echo "find $occurrenceDir -type f -name 'YEAR*'" | sh > $tmpDir/trainingAndValidationFiles.occurrences
cat $tmpDir/trainingAndValidation.years | xargs -I YEAR echo "find $sentenceCountDir -type f -name 'YEAR*'" | sh > $tmpDir/trainingAndValidationFiles.sentenceCounts

cat $tmpDir/trainingAndValidationFiles.cooccurrences | xargs -I FILE ln -s FILE $tmpDir/trainingAndValidation/cooccurrences/
cat $tmpDir/trainingAndValidationFiles.occurrences | xargs -I FILE ln -s FILE $tmpDir/trainingAndValidation/occurrences
cat $tmpDir/trainingAndValidationFiles.sentenceCounts | xargs -I FILE ln -s FILE $tmpDir/trainingAndValidation/sentenceCounts

bash ../MatrixGeneration/mergeMatrix_2keys.sh tmp/trainingAndValidation/cooccurrences/ $outDir/trainingAndValidation.cooccurrences
bash ../MatrixGeneration/mergeMatrix_1key.sh tmp/trainingAndValidation/occurrences $outDir/trainingAndValidation.occurrences
bash ../MatrixGeneration/mergeMatrix_0keys.sh tmp/trainingAndValidation/sentenceCounts $outDir/trainingAndValidation.sentenceCounts



#############
# Training  #
#############

mkdir -p $tmpDir/training/cooccurrences
mkdir -p $tmpDir/training/occurrences
mkdir -p $tmpDir/training/sentenceCounts

find $cooccurrenceDir -type f | xargs -I FILE basename FILE | cut -f 1 -d '.' | sort -n -u | awk -v splitYear=$trainingSplit ' { if ( $1<=splitYear) print; } ' > $tmpDir/training.years

cat $tmpDir/training.years | xargs -I YEAR echo "find $cooccurrenceDir -type f -name 'YEAR*'" | sh > $tmpDir/trainingFiles.cooccurrences
cat $tmpDir/training.years | xargs -I YEAR echo "find $occurrenceDir -type f -name 'YEAR*'" | sh > $tmpDir/trainingFiles.occurrences
cat $tmpDir/training.years | xargs -I YEAR echo "find $sentenceCountDir -type f -name 'YEAR*'" | sh > $tmpDir/trainingFiles.sentenceCounts

cat $tmpDir/trainingFiles.cooccurrences | xargs -I FILE ln -s FILE $tmpDir/training/cooccurrences/
cat $tmpDir/trainingFiles.occurrences | xargs -I FILE ln -s FILE $tmpDir/training/occurrences
cat $tmpDir/trainingFiles.sentenceCounts | xargs -I FILE ln -s FILE $tmpDir/training/sentenceCounts

bash ../MatrixGeneration/mergeMatrix_2keys.sh tmp/training/cooccurrences/ $outDir/training.cooccurrences
bash ../MatrixGeneration/mergeMatrix_1key.sh tmp/training/occurrences $outDir/training.occurrences
bash ../MatrixGeneration/mergeMatrix_0keys.sh tmp/training/sentenceCounts $outDir/training.sentenceCounts

##############
# Validation #
##############

mkdir -p $tmpDir/validation/$splitYear/cooccurrences

ln -s $cooccurrenceDir/$splitYear* $tmpDir/validation/$splitYear/cooccurrences

bash ../MatrixGeneration/mergeMatrix_2keys.sh $tmpDir/validation/$splitYear/cooccurrences $outDir/validation.cooccurrences

bash ../MatrixGeneration/filterMatrix.sh $outDir/validation.cooccurrences $outDir/training.occurrences $outDir/training.cooccurrences $outDir/validation.cooccurrences.tmp
mv $outDir/validation.cooccurrences.tmp $outDir/validation.cooccurrences


########
# Test #
########

cp $outDir/trainingAndValidation.cooccurrences $outDir/tracking.cooccurrences
for testYear in `cat $tmpDir/test.years`
do
	mkdir -p $tmpDir/testing/$testYear/cooccurrences
	#mkdir -p $tmpDir/testing/$testYear/occurrences
	#mkdir -p $tmpDir/testing/$testYear/sentenceCounts

	ln -s $cooccurrenceDir/$testYear* $tmpDir/testing/$testYear/cooccurrences
	#ln -s $occurrenceDir/$testYear* $tmpDir/testing/$testYear/occurrences
	#ln -s $sentenceCountDir/$testYear* $tmpDir/testing/$testYear/sentenceCounts
	
	bash ../MatrixGeneration/mergeMatrix_2keys.sh $tmpDir/testing/$testYear/cooccurrences $outDir/testing.$testYear.cooccurrences

	bash ../MatrixGeneration/filterMatrix.sh $outDir/testing.$testYear.cooccurrences $outDir/trainingAndValidation.occurrences $outDir/tracking.cooccurrences $outDir/testing.$testYear.cooccurrences.tmp
	mv $outDir/testing.$testYear.cooccurrences.tmp $outDir/testing.$testYear.cooccurrences

	sort -R $outDir/testing.$testYear.cooccurrences | head -n $testSize | sort -k1,1n -k2,2n > $outDir/testing.$testYear.subset.$testSize.cooccurrences

	mkdir $tmpDir/tmpMerge
	ln -s $outDir/tracking.cooccurrences $tmpDir/tmpMerge/
	ln -s $outDir/testing.$testYear.cooccurrences $tmpDir/tmpMerge/

	bash ../MatrixGeneration/mergeMatrix_2keys.sh $tmpDir/tmpMerge/ $outDir/tracking.cooccurrences.tmp
	mv $outDir/tracking.cooccurrences.tmp $outDir/tracking.cooccurrences
	rm -fr $tmpDir/tmpMerge
done

bash ../MatrixGeneration/mergeMatrix_2keys.sh "$outDir/testing.*" $outDir/testing.all.cooccurrences

sort -R $outDir/testing.all.cooccurrences | head -n $testSize | sort -k1,1n -k2,2n > $outDir/testing.all.subset.$testSize.cooccurrences
sort -R $outDir/$outDir/validation.cooccurrences | head -n $validationSize | sort -k1,1n -k2,2n > $outDir/$outDir/validation.subset.$validationSize.cooccurrences
