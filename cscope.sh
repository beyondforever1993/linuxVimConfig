#!/bin/bash

export MYPROJECTDIR=`pwd`

echo $MYPROJECTDIR

find $MYPROJECTDIR -name "*.[ch]" -o -name "*.cpp" > $MYPROJECTDIR/cscope.files

sed -i '/i80/d' $MYPROJECTDIR/cscope.files
sed -i '/n72/d' $MYPROJECTDIR/cscope.files
sed -i '/x10/d' $MYPROJECTDIR/cscope.files

echo "Execute the cscope -bqk -i cscope.files command, please wait......"
cscope -bqk -i cscope.files
echo "All OK"

exit 0
