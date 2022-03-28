#!/bin/bash
SCRIPTDIR=$(readlink -f "$0")
CURRENTDIR=$(dirname "$SCRIPTDIR")
TOOLS=$CURRENTDIR/tools
OUT=$CURRENTDIR/out
ZIP=$CURRENTDIR/zip

# update linux
sudo apt update -y; sudo apt upgrade -y 2>>/dev/null
sudo apt install zip unzip python3 brotli simg2img liblzma-dev liblz4-tool -y 2>>/dev/null
sudo apt update --fix-missing 2>>/dev/null

# Comenzando proyecto
set -e
mkdir payload
mkdir out
mkdir zip
cp -af rom/* zip; mkdir $ZIP/firmware-update
unzip -d payload $1 payload.bin 2>/dev/null
#rm -rf $1
python3 $TOOLS/payload.py payload/payload.bin --out payload
echo "unzip images"
python3 $TOOLS/imgextractor.py payload/system.img $OUT/system
systemz=`du -sk $OUT/system/system | awk '{$1*=1024;$1=int($1*1.05);printf $1}'`
python3 $TOOLS/imgextractor.py payload/vendor.img $OUT/vendor
vendorz=`du -sk $OUT/vendor/vendor | awk '{$1*=1024;$1=int($1*1.05);printf $1}'`
python3 $TOOLS/imgextractor.py payload/system_ext.img $OUT/system_ext
system_extz=`du -sk $OUT/system_ext/system_ext | awk '{$1*=1024;$1=int($1*1.05);printf $1}'`
python3 $TOOLS/imgextractor.py payload/product.img $OUT/product
productz=`du -sk $OUT/product/product | awk '{$1*=1024;$1=int($1*1.05);printf $1}'`
python3 $TOOLS/imgextractor.py payload/odm.img $OUT/odm
odmz=`du -sk $OUT/odm | awk '{$1*=1024;$1=int($1*1.05);printf $1}'`
# Delete images
cd $CURRENTDIR/payload
rm -rf  system.img vendor.img system_ext.img product.img odm.img payload.py requirements.txt update_payload payload.bin
mv * $ZIP/firmware-update
cd $CURRENTDIR
# Version
ROMVERSION=$(grep ro.system.build.version.incremental= $OUT/system/system/system/build.prop | sed "s/ro.system.build.version.incremental=//g"; )
ROMANDROID=$(grep ro.build.version.release= $OUT/system/system/system/build.prop | sed "s/ro.build.version.release=//g"; )
ROMBUILD=$(grep ro.build.id= $OUT/system/system/system/build.prop | sed "s/ro.build.id=//g"; )
# dfe
echo "delete encryptation"
sed -i "s/fileencryption=/encryptable=ice:/g" $OUT/vendor/vendor/etc/fstab.qcom
echo "creando images"
cd $OUT/system
$TOOLS/mkuserimg_mke2fs.sh "system" "system.img" "ext4" "/system" $systemz -j "0" -T "1230768000" -C "config/system_fs_config" -L "system" -I "256" -M "/system" -m "0" "config/system_file_contexts"
mv system.img $OUT
rm -rf ../system
cd $OUT/vendor
$TOOLS/mkuserimg_mke2fs.sh "vendor" "vendor.img" "ext4" "/vendor " $vendorz  -j "0" -T "1230768000" -C "config/vendor_fs_config" -L "vendor" -I "256" -M "/vendor" -m "0" "config/vendor_file_contexts"
mv vendor.img $OUT
rm -rf ../vendor
cd $OUT/system_ext
$TOOLS/mkuserimg_mke2fs.sh "system_ext" "system_ext.img" "ext4" "/system_ext" $system_extz -j "0" -T "1230768000" -C "config/system_ext_fs_config" -L "system_ext" -I "256" -M "/system_ext" -m "0" "config/system_ext_file_contexts"
mv system_ext.img $OUT
rm -rf ../system_ext
cd $OUT/product
$TOOLS/mkuserimg_mke2fs.sh "product" "product.img" "ext4" "/product" $productz -j "0" -T "1230768000" -C "config/product_fs_config" -L "product" -I "256" -M "/product" -m "0" "config/product_file_contexts"
mv product.img $OUT
rm -rf ../product
cd $OUT/odm
$TOOLS/mkuserimg_mke2fs.sh "odm" "odm.img" "ext4" "/odm" $odmz -j "0" -T "1230768000" -C "config/odm_fs_config" -L "odm" -I "256" -M "/odm" -m "0" "config/odm_file_contexts"
mv odm.img $OUT
rm -rf ../odm
cd $OUT
# configs dynamic list
systemop=`du -b system.img | awk '{print $1}'`
sed -i "s/systemop/$systemop/g" $ZIP/dynamic_partitions_op_list
system_extop=`du -b system_ext.img | awk '{print $1}'`
sed -i "s/system_extop/$system_extop/g" $ZIP/dynamic_partitions_op_list
vendorop=`du -b vendor.img | awk '{print $1}'`
sed -i "s/vendorop/$vendorop/g" $ZIP/dynamic_partitions_op_list
productop=`du -b product.img | awk '{print $1}'`
sed -i "s/productop/$productop/g" $ZIP/dynamic_partitions_op_list
odmop=`du -b odm.img | awk '{print $1}'`
sed -i "s/odmop/$odmop/g" $ZIP/dynamic_partitions_op_list
# rw-sparse
img2simg system.img systemrw.img; rm -rf system.img
img2simg product.img productrw.img; rm -rf product.img
img2simg system_ext.img system_extrw.img; rm -rf system_ext.img
img2simg vendor.img vendorrw.img; rm -rf vendor.img
img2simg odm.img odmrw.img; rm -rf odm.img
# sparse a dat
$TOOLS/img2sdat/img2sdat.py -v 4 -o $ZIP -p system systemrw.img
$TOOLS/img2sdat/img2sdat.py -v 4 -o $ZIP -p system_ext system_extrw.img
$TOOLS/img2sdat/img2sdat.py -v 4 -o $ZIP -p vendor vendorrw.img
$TOOLS/img2sdat/img2sdat.py -v 4 -o $ZIP -p product productrw.img
$TOOLS/img2sdat/img2sdat.py -v 4 -o $ZIP -p odm odmrw.img
# brotli
cd $ZIP
brotli -j -v -q 6 system.new.dat
brotli -j -v -q 6 system_ext.new.dat
brotli -j -v -q 6 vendor.new.dat
brotli -j -v -q 6 product.new.dat
brotli -j -v -q 6 odm.new.dat
# Empaquetando
zip -ry MIUI_Alioth_$ROMVERSION-$ROMBUILD-v$ROMANDROID.zip *
mv *zip $CURRENTDIR
echo "listo"

 
