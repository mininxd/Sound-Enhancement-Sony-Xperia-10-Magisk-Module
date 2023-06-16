# space
ui_print " "

# log
if [ "$BOOTMODE" != true ]; then
  FILE=/sdcard/$MODID\_recovery.log
  ui_print "- Log will be saved at $FILE"
  exec 2>$FILE
  ui_print " "
fi

# run
. $MODPATH/function.sh

# info
MODVER=`grep_prop version $MODPATH/module.prop`
MODVERCODE=`grep_prop versionCode $MODPATH/module.prop`
ui_print " ID=$MODID"
ui_print " Version=$MODVER"
ui_print " VersionCode=$MODVERCODE"
if [ "$KSU" == true ]; then
  ui_print " KSUVersion=$KSU_VER"
  ui_print " KSUVersionCode=$KSU_VER_CODE"
  ui_print " KSUKernelVersionCode=$KSU_KERNEL_VER_CODE"
  sed -i 's|#k||g' $MODPATH/post-fs-data.sh
else
  ui_print " MagiskVersion=$MAGISK_VER"
  ui_print " MagiskVersionCode=$MAGISK_VER_CODE"
fi
ui_print " "

# sdk
NUM=28
if [ "$API" -lt $NUM ]; then
  ui_print "! Unsupported SDK $API. You have to upgrade your"
  ui_print "  Android version at least SDK API $NUM to use this module."
  abort
else
  ui_print "- SDK $API"
  ui_print " "
fi

# recovery
mount_partitions_in_recovery

# magisk
magisk_setup

# path
SYSTEM=`realpath $MIRROR/system`
PRODUCT=`realpath $MIRROR/product`
VENDOR=`realpath $MIRROR/vendor`
SYSTEM_EXT=`realpath $MIRROR/system_ext`
if [ "$BOOTMODE" == true ]; then
  if [ ! -d $MIRROR/odm ]; then
    mount_odm_to_mirror
  fi
  if [ ! -d $MIRROR/my_product ]; then
    mount_my_product_to_mirror
  fi
fi
ODM=`realpath $MIRROR/odm`
MY_PRODUCT=`realpath $MIRROR/my_product`

# optionals
OPTIONALS=/sdcard/optionals.prop
if [ ! -f $OPTIONALS ]; then
  touch $OPTIONALS
fi

# .aml.sh
mv -f $MODPATH/aml.sh $MODPATH/.aml.sh

# function
check_function() {
if [ "$IS64BIT" == true ]; then
  LISTS=`strings $MODPATH/system_dolby/vendor/lib64/$DES | grep ^lib | grep .so`
  FILE=`for LIST in $LISTS; do echo $SYSTEM/lib64/$LIST; done`
  ui_print "- Checking"
  ui_print "$NAME"
  ui_print "  function at"
  ui_print "$FILE"
  ui_print "  Please wait..."
  if ! grep -q $NAME $FILE; then
    ui_print "  Using new $LIB 64"
    mv -f $MODPATH/system_support/lib64/$LIB $MODPATH/system/lib64
  fi
  ui_print " "
fi
LISTS=`strings $MODPATH/system_dolby/vendor/lib/$DES | grep ^lib | grep .so`
FILE=`for LIST in $LISTS; do echo $SYSTEM/lib/$LIST; done`
ui_print "- Checking"
ui_print "$NAME"
ui_print "  function at"
ui_print "$FILE"
ui_print "  Please wait..."
if ! grep -q $NAME $FILE; then
  ui_print "  Using new $LIB"
  mv -f $MODPATH/system_support/lib/$LIB $MODPATH/system/lib
fi
ui_print " "
}

# bit
if [ "$IS64BIT" == true ]; then
  ui_print "- 64 bit"
  ui_print " "
  if [ "`grep_prop se.dolby $OPTIONALS`" != 0 ]; then
    ui_print "- Activating Dolby Atmos..."
    ui_print " "
    # check
    NAME=_ZN7android8hardware23getOrCreateCachedBinderEPNS_4hidl4base4V1_05IBaseE
    DES=vendor.dolby.hardware.dms@1.0.so
    LIB=libhidlbase.so
    DOLBY=true
    check_function
    MODNAME2='Sound Enhancement Xperia 10 and Dolby Atmos Xperia 1 II'
    sed -i "s/$MODNAME/$MODNAME2/g" $MODPATH/module.prop
    MODNAME=$MODNAME2
    sed -i 's/#d//g' $MODPATH/.aml.sh
    sed -i 's/#d//g' $MODPATH/*.sh
    cp -rf $MODPATH/system_dolby/* $MODPATH/system
  else
    DOLBY=false
  fi
else
  ui_print "- 32 bit"
  rm -rf `find $MODPATH -type d -name *64*`
  DOLBY=false
  if [ "`grep_prop se.dolby $OPTIONALS`" != 0 ]; then
    ui_print "  ! Unsupported Dolby Atmos."
  fi
  ui_print " "
fi
rm -rf $MODPATH/system_dolby

# sepolicy
FILE=$MODPATH/sepolicy.rule
DES=$MODPATH/sepolicy.pfsd
if [ "`grep_prop sepolicy.sh $OPTIONALS`" == 1 ]\
&& [ -f $FILE ]; then
  mv -f $FILE $DES
fi

# mod ui
MOD_UI=false
if [ "`grep_prop mod.ui $OPTIONALS`" == 1 ]; then
  APP=SoundEnhancement
  FILE=/sdcard/$APP.apk
  DIR=`find $MODPATH/system -type d -name $APP`
  ui_print "- Using modified UI apk..."
  if [ -f $FILE ]; then
    cp -f $FILE $DIR
    chmod 0644 $DIR/$APP.apk
    ui_print "  Applied"
    MOD_UI=true
  else
    ui_print "  ! There is no $FILE file."
    ui_print "    Please place the apk to your internal storage first"
    ui_print "    and reflash!"
  fi
  ui_print " "
fi

# stream mode
PROP=`grep_prop stream.mode $OPTIONALS`
if [ "$MOD_UI" != true ] && echo "$PROP" | grep -q m; then
  ui_print "- Using Sound Enhancement post process music stream..."
  cp -rf $MODPATH/system_post_process/* $MODPATH/system
  ui_print " "
fi
rm -rf $MODPATH/system_post_process

# cleaning
ui_print "- Cleaning..."
if [ $DOLBY == true ]; then
  PKG=`cat $MODPATH/package-dolby.txt`
  rm -f /data/vendor/dolby/dax_sqlite3.db
else
  PKG=`cat $MODPATH/package.txt`
fi
if [ "$BOOTMODE" == true ]; then
  for PKGS in $PKG; do
    RES=`pm uninstall $PKGS 2>/dev/null`
  done
fi
rm -rf $MODPATH/unused
remove_sepolicy_rule
ui_print " "
# power save
FILE=$MODPATH/system/etc/sysconfig/*
if [ "`grep_prop power.save $OPTIONALS`" == 1 ]; then
  ui_print "- $MODNAME will not be allowed in power save."
  ui_print "  It may save your battery but decreasing $MODNAME performance."
  for PKGS in $PKG; do
    sed -i "s/<allow-in-power-save package=\"$PKGS\"\/>//g" $FILE
    sed -i "s/<allow-in-power-save package=\"$PKGS\" \/>//g" $FILE
  done
  ui_print " "
fi

# function
conflict() {
for NAME in $NAMES; do
  DIR=/data/adb/modules_update/$NAME
  if [ -f $DIR/uninstall.sh ]; then
    sh $DIR/uninstall.sh
  fi
  rm -rf $DIR
  DIR=/data/adb/modules/$NAME
  rm -f $DIR/update
  touch $DIR/remove
  FILE=/data/adb/modules/$NAME/uninstall.sh
  if [ -f $FILE ]; then
    sh $FILE
    rm -f $FILE
  fi
  rm -rf /metadata/magisk/$NAME
  rm -rf /mnt/vendor/persist/magisk/$NAME
  rm -rf /persist/magisk/$NAME
  rm -rf /data/unencrypted/magisk/$NAME
  rm -rf /cache/magisk/$NAME
  rm -rf /cust/magisk/$NAME
done
}

# conflict
if [ $DOLBY == true ]; then
  NAMES="dolbyatmos DolbyAtmos DolbyAudio MotoDolby
         dsplus Dolby"
  conflict
  NAMES=MiSound
  FILE=/data/adb/modules/$NAMES/module.prop
  if grep -q 'and Dolby Atmos' $FILE; then
    conflict
  fi
fi

# function
cleanup() {
if [ -f $DIR/uninstall.sh ]; then
  sh $DIR/uninstall.sh
fi
DIR=/data/adb/modules_update/$MODID
if [ -f $DIR/uninstall.sh ]; then
  sh $DIR/uninstall.sh
fi
}

# cleanup
DIR=/data/adb/modules/$MODID
FILE=$DIR/module.prop
if [ "`grep_prop data.cleanup $OPTIONALS`" == 1 ]; then
  sed -i 's/^data.cleanup=1/data.cleanup=0/' $OPTIONALS
  ui_print "- Cleaning-up $MODID data..."
  cleanup
  ui_print " "
elif [ -d $DIR ] && ! grep -q "$MODNAME" $FILE; then
  ui_print "- Different version detected"
  ui_print "  Cleaning-up $MODID data..."
  cleanup
  ui_print " "
fi

# function
permissive_2() {
sed -i 's|#2||g' $MODPATH/post-fs-data.sh
}
permissive() {
FILE=/sys/fs/selinux/enforce
SELINUX=`cat $FILE`
if [ "$SELINUX" == 1 ]; then
  if ! setenforce 0; then
    echo 0 > $FILE
  fi
  SELINUX=`cat $FILE`
  if [ "$SELINUX" == 1 ]; then
    ui_print "  Your device can't be turned to Permissive state."
    ui_print "  Using Magisk Permissive mode instead."
    permissive_2
  else
    if ! setenforce 1; then
      echo 1 > $FILE
    fi
    sed -i 's|#1||g' $MODPATH/post-fs-data.sh
  fi
else
  sed -i 's|#1||g' $MODPATH/post-fs-data.sh
fi
}
backup() {
if [ ! -f $FILE.orig ] && [ ! -f $FILE.bak ]; then
  cp -af $FILE $FILE.orig
fi
}
patch_manifest() {
if [ -f $FILE ]; then
  backup
  if [ -f $FILE.orig ] || [ -f $FILE.bak ]; then
    ui_print "- Created"
    ui_print "$FILE.orig"
    ui_print " "
    ui_print "- Patching"
    ui_print "$FILE"
    ui_print "  directly..."
    sed -i '/<manifest/a\
    <hal format="hidl">\
        <name>vendor.dolby.hardware.dms</name>\
        <transport>hwbinder</transport>\
        <version>1.0</version>\
        <interface>\
            <name>IDms</name>\
            <instance>default</instance>\
        </interface>\
        <fqname>@1.0::IDms/default</fqname>\
    </hal>' $FILE
    ui_print " "
  else
    ui_print "- Failed to create"
    ui_print "$FILE.orig"
    ui_print " "
  fi
fi
}
patch_hwservice() {
if [ -f $FILE ]; then
  backup
  if [ -f $FILE.orig ] || [ -f $FILE.bak ]; then
    ui_print "- Created"
    ui_print "$FILE.orig"
    ui_print " "
    ui_print "- Patching"
    ui_print "$FILE"
    ui_print "  directly..."
    sed -i '1i\
vendor.dolby.hardware.dms::IDms u:object_r:hal_dms_hwservice:s0' $FILE
    ui_print " "
  else
    ui_print "- Failed to create"
    ui_print "$FILE.orig"
    ui_print " "
  fi
fi
}
early_init_mount_dir() {
if echo $MAGISK_VER | grep -q delta\
&& [ "`grep_prop dolby.skip.early $OPTIONALS`" != 1 ]; then
  EIM=true
  ACTIVEEIMDIR=$MAGISKTMP/mirror/early-mount
  if [ -L $ACTIVEEIMDIR ]; then
    EIMDIR=`readlink $ACTIVEEIMDIR`
    [ "${EIMDIR:0:1}" != "/" ] && EIMDIR="$MAGISKTMP/mirror/$EIMDIR"
  elif ! $ISENCRYPTED; then
    EIMDIR=/data/adb/early-mount.d
  elif [ -d /data/unencrypted ]\
  && ! grep ' /data ' /proc/mounts | grep -Eq 'dm-|f2fs'; then
    EIMDIR=/data/unencrypted/early-mount.d
  elif grep ' /cache ' /proc/mounts | grep -q 'ext4'; then
    EIMDIR=/cache/early-mount.d
  elif grep ' /metadata ' /proc/mounts | grep -q 'ext4'; then
    EIMDIR=/metadata/early-mount.d
  elif grep ' /persist ' /proc/mounts | grep -q 'ext4'; then
    EIMDIR=/persist/early-mount.d
  elif grep ' /mnt/vendor/persist ' /proc/mounts | grep -q 'ext4'; then
    EIMDIR=/mnt/vendor/persist/early-mount.d
  elif grep ' /cust ' /proc/mounts | grep -Eq 'ext4|f2fs'; then
    EIMDIR=/cust/early-mount.d
  else
    EIM=false
    ui_print "- Unable to find early init mount directory"
    ui_print " "
  fi
  if [ -d ${EIMDIR%/early-mount.d} ]; then
    mkdir -p $EIMDIR
    ui_print "- Your early init mount directory is"
    ui_print "  $EIMDIR"
    ui_print " "
    ui_print "  Any file stored to this directory will not be deleted even"
    ui_print "  you have uninstalled this module."
  else
    EIM=false
    ui_print "- Unable to find early init mount directory ${EIMDIR%/early-mount.d}"
  fi
  ui_print " "
else
  EIM=false
fi
}
find_file() {
for NAME in $NAMES; do
  if [ "$IS64BIT" == true ]; then
    FILE=`find $SYSTEM/lib64 $VENDOR/lib64 $SYSTEM_EXT/lib64 -type f -name $NAME`
    if [ ! "$FILE" ]; then
      if [ "`grep_prop install.hwlib $OPTIONALS`" == 1 ]; then
        ui_print "- Installing $NAME 64 directly to"
        ui_print "$SYSTEM/lib64..."
        cp $MODPATH/system_support/lib64/$NAME $SYSTEM/lib64
        DES=$SYSTEM/lib64/$NAME
        if [ -f $MODPATH/system_support/lib64/$NAME ]\
        && [ ! -f $DES ]; then
          ui_print "  ! Installation failed."
          ui_print "    Using $NAME 64 systemlessly."
          cp -f $MODPATH/system_support/lib64/$NAME $MODPATH/system/lib64
        fi
      else
        ui_print "! $NAME 64 not found."
        ui_print "  Using $NAME 64 systemlessly."
        cp -f $MODPATH/system_support/lib64/$NAME $MODPATH/system/lib64
        ui_print "  If this module still doesn't work, type:"
        ui_print "  install.hwlib=1"
        ui_print "  inside $OPTIONALS"
        ui_print "  and reinstall this module"
        ui_print "  to install $NAME 64 directly to this ROM."
        ui_print "  DwYOR!"
      fi
      ui_print " "
    fi
  fi
  FILE=`find $SYSTEM/lib $VENDOR/lib $SYSTEM_EXT/lib -type f -name $NAME`
  if [ ! "$FILE" ]; then
    if [ "`grep_prop install.hwlib $OPTIONALS`" == 1 ]; then
      ui_print "- Installing $NAME directly to"
      ui_print "$SYSTEM/lib..."
      cp $MODPATH/system_support/lib/$NAME $SYSTEM/lib
      DES=$SYSTEM/lib/$NAME
      if [ -f $MODPATH/system_support/lib/$NAME ]\
      && [ ! -f $DES ]; then
        ui_print "  ! Installation failed."
        ui_print "    Using $NAME systemlessly."
        cp -f $MODPATH/system_support/lib/$NAME $MODPATH/system/lib
      fi
    else
      ui_print "! $NAME not found."
      ui_print "  Using $NAME systemlessly."
      cp -f $MODPATH/system_support/lib/$NAME $MODPATH/system/lib
      ui_print "  If this module still doesn't work, type:"
      ui_print "  install.hwlib=1"
      ui_print "  inside $OPTIONALS"
      ui_print "  and reinstall this module"
      ui_print "  to install $NAME directly to this ROM."
      ui_print "  DwYOR!"
    fi
    ui_print " "
  fi
done
sed -i 's|^install.hwlib=1|install.hwlib=0|g' $OPTIONALS
}
patch_manifest_eim() {
if [ $EIM == true ]; then
  SRC=$SYSTEM/etc/vintf/manifest.xml
  if [ -f $SRC ]; then
    DIR=$EIMDIR/system/etc/vintf
    DES=$DIR/manifest.xml
    mkdir -p $DIR
    if [ ! -f $DES ]; then
      cp -af $SRC $DIR
    fi
    if ! grep -A2 vendor.dolby.hardware.dms $DES | grep -q 1.0; then
      ui_print "- Patching"
      ui_print "$SRC"
      ui_print "  systemlessly using early init mount..."
      sed -i '/<manifest/a\
    <hal format="hidl">\
        <name>vendor.dolby.hardware.dms</name>\
        <transport>hwbinder</transport>\
        <version>1.0</version>\
        <interface>\
            <name>IDms</name>\
            <instance>default</instance>\
        </interface>\
        <fqname>@1.0::IDms/default</fqname>\
    </hal>' $DES
      ui_print " "
    fi
  else
    EIM=false
  fi
fi
}
patch_hwservice_eim() {
if [ $EIM == true ]; then
  SRC=$SYSTEM/etc/selinux/plat_hwservice_contexts
  if [ -f $SRC ]; then
    DIR=$EIMDIR/system/etc/selinux
    DES=$DIR/plat_hwservice_contexts
    mkdir -p $DIR
    if [ ! -f $DES ]; then
      cp -af $SRC $DIR
    fi
    if ! grep -Eq 'u:object_r:hal_dms_hwservice:s0|u:object_r:default_android_hwservice:s0' $DES; then
      ui_print "- Patching"
      ui_print "$SRC"
      ui_print "  systemlessly using early init mount..."
      sed -i '1i\
vendor.dolby.hardware.dms::IDms u:object_r:hal_dms_hwservice:s0' $DES
      ui_print " "
    fi
  else
    EIM=false
  fi
fi
}

# permissive
if [ "`grep_prop permissive.mode $OPTIONALS`" == 1 ]; then
  ui_print "- Using device Permissive mode."
  rm -f $MODPATH/sepolicy.rule
  permissive
  ui_print " "
elif [ "`grep_prop permissive.mode $OPTIONALS`" == 2 ]; then
  ui_print "- Using Magisk Permissive mode."
  rm -f $MODPATH/sepolicy.rule
  permissive_2
  ui_print " "
fi

# mod ui
MOD_UI_DOLBY=false
if [ $DOLBY == true ]\
&& [ "`grep_prop mod.ui $OPTIONALS`" == 1 ]; then
  APP=DaxUI
  FILE=/sdcard/$APP.apk
  DIR=`find $MODPATH/system -type d -name $APP`
  ui_print "- Using modified Dolby UI apk..."
  if [ -f $FILE ]; then
    cp -f $FILE $DIR
    chmod 0644 $DIR/$APP.apk
    ui_print "  Applied"
    MOD_UI_DOLBY=true
  else
    ui_print "  ! There is no $FILE file."
    ui_print "    Please place the apk to your internal storage first"
    ui_print "    and reflash!"
  fi
  ui_print " "
fi

# 36 dB
PROP=`grep_prop dolby.gain $OPTIONALS`
if [ $DOLBY == true ] && [ "$MOD_UI_DOLBY" != true ]\
&& [ "$PROP" ] && [ "$PROP" -gt 192 ]; then
  ui_print "- Using max/min limit 36 dB for Dolby Atmos"
  cp -rf $MODPATH/system_dolby_36dB/* $MODPATH/system
  ui_print " "
fi
rm -rf $MODPATH/system_dolby_36dB

# remount
if [ $DOLBY == true ]; then
  remount_rw
fi

# early init mount dir
if [ $DOLBY == true ]; then
  early_init_mount_dir
fi

# check
chcon -R u:object_r:system_lib_file:s0 $MODPATH/system_support/lib*
NAMES="libhidltransport.so libhwbinder.so"
if [ $DOLBY == true ]; then
  find_file
fi
rm -rf $MODPATH/system_support

# patch manifest.xml
if [ $DOLBY == true ]; then
  FILE="$MAGISKTMP/mirror/*/etc/vintf/manifest.xml
        $MAGISKTMP/mirror/*/*/etc/vintf/manifest.xml
        /*/etc/vintf/manifest.xml /*/*/etc/vintf/manifest.xml
        $MAGISKTMP/mirror/*/etc/vintf/manifest/*.xml
        $MAGISKTMP/mirror/*/*/etc/vintf/manifest/*.xml
        /*/etc/vintf/manifest/*.xml /*/*/etc/vintf/manifest/*.xml"
  if [ "`grep_prop dolby.skip.vendor $OPTIONALS`" != 1 ]\
  && ! grep -A2 vendor.dolby.hardware.dms $FILE | grep -q 1.0; then
    FILE=$VENDOR/etc/vintf/manifest.xml
    patch_manifest
  fi
  if [ "`grep_prop dolby.skip.system $OPTIONALS`" != 1 ]\
  && ! grep -A2 vendor.dolby.hardware.dms $FILE | grep -q 1.0; then
    FILE=$SYSTEM/etc/vintf/manifest.xml
    patch_manifest
  fi
  if [ "`grep_prop dolby.skip.system_ext $OPTIONALS`" != 1 ]\
  && ! grep -A2 vendor.dolby.hardware.dms $FILE | grep -q 1.0; then
    FILE=$SYSTEM_EXT/etc/vintf/manifest.xml
    patch_manifest
  fi
  if ! grep -A2 vendor.dolby.hardware.dms $FILE | grep -q 1.0; then
    patch_manifest_eim
    if [ $EIM == false ]; then
      ui_print "- Using systemless manifest.xml patch."
      ui_print "  On some ROMs, it causes bugs or even makes bootloop"
      ui_print "  because not allowed to restart hwservicemanager."
      ui_print "  You can fix this by using Magisk Delta."
      ui_print " "
    fi
    FILES="$MAGISKTMP/mirror/*/etc/vintf/manifest.xml
           $MAGISKTMP/mirror/*/*/etc/vintf/manifest.xml
           /*/etc/vintf/manifest.xml /*/*/etc/vintf/manifest.xml"
    restore
  fi
fi

# patch hwservice contexts
if [ $DOLBY == true ]; then
  FILE="$MAGISKTMP/mirror/*/etc/selinux/*_hwservice_contexts
        $MAGISKTMP/mirror/*/*/etc/selinux/*_hwservice_contexts
        /*/etc/selinux/*_hwservice_contexts
        /*/*/etc/selinux/*_hwservice_contexts"
  if [ "`grep_prop dolby.skip.vendor $OPTIONALS`" != 1 ]\
  && ! grep -Eq 'u:object_r:hal_dms_hwservice:s0|u:object_r:default_android_hwservice:s0' $FILE; then
    FILE=$VENDOR/etc/selinux/vendor_hwservice_contexts
    patch_hwservice
  fi
  if [ "`grep_prop dolby.skip.system $OPTIONALS`" != 1 ]\
  && ! grep -Eq 'u:object_r:hal_dms_hwservice:s0|u:object_r:default_android_hwservice:s0' $FILE; then
    FILE=$SYSTEM/etc/selinux/plat_hwservice_contexts
    patch_hwservice
  fi
  if [ "`grep_prop dolby.skip.system_ext $OPTIONALS`" != 1 ]\
   && ! grep -Eq 'u:object_r:hal_dms_hwservice:s0|u:object_r:default_android_hwservice:s0' $FILE; then
    FILE=$SYSTEM_EXT/etc/selinux/system_ext_hwservice_contexts
    patch_hwservice
  fi
  if ! grep -Eq 'u:object_r:hal_dms_hwservice:s0|u:object_r:default_android_hwservice:s0' $FILE; then
    patch_hwservice_eim
    if [ $EIM == false ]; then
      ui_print "! Failed to set hal_dms_hwservice context."
      ui_print " "
    fi
    FILES="$MAGISKTMP/mirror/*/etc/selinux/*_hwservice_contexts
           $MAGISKTMP/mirror/*/*/etc/selinux/*_hwservice_contexts
           /*/etc/selinux/*_hwservice_contexts
           /*/*/etc/selinux/*_hwservice_contexts"
    restore
  fi
fi

# remount
if [ $DOLBY == true ]; then
  remount_ro
fi

# function
hide_oat() {
for APPS in $APP; do
  REPLACE="$REPLACE
  `find $MODPATH/system -type d -name $APPS | sed "s|$MODPATH||"`/oat"
done
}
replace_dir() {
if [ -d $DIR ]; then
  REPLACE="$REPLACE $MODDIR"
fi
}
hide_app() {
DIR=$SYSTEM/app/$APPS
MODDIR=/system/app/$APPS
replace_dir
DIR=$SYSTEM/priv-app/$APPS
MODDIR=/system/priv-app/$APPS
replace_dir
DIR=$PRODUCT/app/$APPS
MODDIR=/system/product/app/$APPS
replace_dir
DIR=$PRODUCT/priv-app/$APPS
MODDIR=/system/product/priv-app/$APPS
replace_dir
DIR=$MY_PRODUCT/app/$APPS
MODDIR=/system/product/app/$APPS
replace_dir
DIR=$MY_PRODUCT/priv-app/$APPS
MODDIR=/system/product/priv-app/$APPS
replace_dir
DIR=$PRODUCT/preinstall/$APPS
MODDIR=/system/product/preinstall/$APPS
replace_dir
DIR=$SYSTEM_EXT/app/$APPS
MODDIR=/system/system_ext/app/$APPS
replace_dir
DIR=$SYSTEM_EXT/priv-app/$APPS
MODDIR=/system/system_ext/priv-app/$APPS
replace_dir
DIR=$VENDOR/app/$APPS
MODDIR=/system/vendor/app/$APPS
replace_dir
DIR=$VENDOR/euclid/product/app/$APPS
MODDIR=/system/vendor/euclid/product/app/$APPS
replace_dir
}

# hide
APP="`ls $MODPATH/system/priv-app` `ls $MODPATH/system/app`"
hide_oat
APP="MusicFX AudioFX"
for APPS in $APP; do
  hide_app
done
if [ $DOLBY == true ]; then
  APP="MotoDolbyDax3 MotoDolbyV3 OPSoundTuner DolbyAtmos AudioEffectCenter"
  for APPS in $APP; do
    hide_app
  done
fi

# function
stream_mode() {
FILE=$MODPATH/.aml.sh
PROP=`grep_prop stream.mode $OPTIONALS`
if echo "$PROP" | grep -q m; then
  ui_print "- Activating music stream..."
  sed -i 's|#m||g' $FILE
  ui_print " "
# else
#   ui_print "- Sound Enhancement post process effect is disabled"
#   ui_print "  for Dolby Atmos global effect"
#   sed -i 's/persist.sony.effect.dolby_atmos false/persist.sony.effect.dolby_atmos true/g' $MODPATH/service.sh
#   sed -i 's/persist.sony.effect.ahc true/persist.sony.effect.ahc false/g' $MODPATH/service.sh
#   ui_print " "
fi
if echo "$PROP" | grep -q r; then
  ui_print "- Activating ring stream..."
  sed -i 's|#r||g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -q a; then
  ui_print "- Activating alarm stream..."
  sed -i 's|#a||g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -q s; then
  ui_print "- Activating system stream..."
  sed -i 's|#s||g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -q v; then
  ui_print "- Activating voice_call stream..."
  sed -i 's|#v||g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -q n; then
  ui_print "- Activating notification stream..."
  sed -i 's|#n||g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -q b; then
  ui_print "- Activating bluetooth_sco stream..."
  sed -i 's|#b||g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -q f; then
  ui_print "- Activating dtmf stream..."
  sed -i 's|#f||g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -q e; then
  ui_print "- Activating enforced_audible stream..."
  sed -i 's|#e||g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -q y; then
  ui_print "- Activating accessibility stream..."
  sed -i 's|#y||g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -q t; then
  ui_print "- Activating tts stream..."
  sed -i 's|#t||g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -q i; then
  ui_print "- Activating assistant stream..."
  sed -i 's|#i||g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -q c; then
  ui_print "- Activating call_assistant stream..."
  sed -i 's|#c||g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -q p; then
  ui_print "- Activating patch stream..."
  sed -i 's|#p||g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -q g; then
  ui_print "- Activating rerouting stream..."
  sed -i 's|#g||g' $FILE
  ui_print " "
fi
}

# stream mode
if [ $DOLBY == true ]; then
  stream_mode
fi

# function
dolby_settings() {
FILE=$MODPATH/system/vendor/etc/dolby/dax-default.xml
PROP=`grep_prop dolby.bass $OPTIONALS`
if [ "$PROP" == def ]; then
  ui_print "- Using default settings of bass-enhancer"
elif [ "$PROP" == true ]; then
  ui_print "- Changing all bass-enhancer-enable value to true"
  sed -i 's|bass-enhancer-enable value="false"|bass-enhancer-enable value="true"|g' $FILE
elif [ "$PROP" ] && [ "$PROP" != false ] && [ "$PROP" -gt 0 ]; then
  ui_print "- Changing all bass-enhancer-enable value to true"
  sed -i 's|bass-enhancer-enable value="false"|bass-enhancer-enable value="true"|g' $FILE
  ROWS=`grep bass-enhancer-boost $FILE | sed -e 's|<bass-enhancer-boost value="||g' -e 's|"/>||g'`
  ui_print "- Default bass-enhancer-boost value:"
  ui_print "$ROWS"
  ui_print "- Changing all bass-enhancer-boost value to $PROP"
  for ROW in $ROWS; do
    sed -i "s|bass-enhancer-boost value=\"$ROW\"|bass-enhancer-boost value=\"$PROP\"|g" $FILE
  done
else
  ui_print "- Changing all bass-enhancer-enable value to false"
  sed -i 's|bass-enhancer-enable value="true"|bass-enhancer-enable value="false"|g' $FILE
fi
if [ "`grep_prop dolby.virtualizer $OPTIONALS`" == 1 ]; then
  ui_print "- Changing all virtualizer-enable value to true"
  sed -i 's|virtualizer-enable value="false"|virtualizer-enable value="true"|g' $FILE
elif [ "`grep_prop dolby.virtualizer $OPTIONALS`" == 0 ]; then
  ui_print "- Changing all virtualizer-enable value to false"
  sed -i 's|virtualizer-enable value="true"|virtualizer-enable value="false"|g' $FILE
fi
if [ "`grep_prop dolby.volumeleveler $OPTIONALS`" == def ]; then
  ui_print "- Using default settings of volume-leveler"
elif [ "`grep_prop dolby.volumeleveler $OPTIONALS`" == 1 ]; then
  ui_print "- Changing all volume-leveler-enable value to true"
  sed -i 's|volume-leveler-enable value="false"|volume-leveler-enable value="true"|g' $FILE
else
  ui_print "- Changing all volume-leveler-enable value to false"
  sed -i 's|volume-leveler-enable value="true"|volume-leveler-enable value="false"|g' $FILE
fi
if [ "`grep_prop dolby.deepbass $OPTIONALS`" == 1 ]; then
  ui_print "- Using deeper bass GEQ frequency"
  sed -i 's/frequency="47"/frequency="0"/g' $FILE
  sed -i 's/frequency="141"/frequency="47"/g' $FILE
  sed -i 's/frequency="234"/frequency="141"/g' $FILE
  sed -i 's/frequency="328"/frequency="234"/g' $FILE
  sed -i 's/frequency="469"/frequency="328"/g' $FILE
  sed -i 's/frequency="656"/frequency="469"/g' $FILE
  sed -i 's/frequency="844"/frequency="656"/g' $FILE
  sed -i 's/frequency="1031"/frequency="844"/g' $FILE
  sed -i 's/frequency="1313"/frequency="1031"/g' $FILE
  sed -i 's/frequency="1688"/frequency="1313"/g' $FILE
  sed -i 's/frequency="2250"/frequency="1688"/g' $FILE
  sed -i 's/frequency="3000"/frequency="2250"/g' $FILE
  sed -i 's/frequency="3750"/frequency="3000"/g' $FILE
  sed -i 's/frequency="4688"/frequency="3750"/g' $FILE
  sed -i 's/frequency="5813"/frequency="4688"/g' $FILE
  sed -i 's/frequency="7125"/frequency="5813"/g' $FILE
  sed -i 's/frequency="9000"/frequency="7125"/g' $FILE
  sed -i 's/frequency="11250"/frequency="9000"/g' $FILE
  sed -i 's/frequency="13875"/frequency="11250"/g' $FILE
  sed -i 's/frequency="19688"/frequency="13875"/g' $FILE
fi
ui_print " "
}

# settings
if [ $DOLBY == true ]; then
  dolby_settings
fi

# check
NAME=dsee_hx_state
FILE=$VENDOR/lib*/hw/audio.primary.*.so
if grep -q "$NAME" $FILE ; then
  ui_print "- Detected DSEEHX support in"
  ui_print "$FILE"
  sed -i 's/ro.somc.dseehx.supported true/ro.somc.dseehx.supported false/g' $MODPATH/service.sh
  ui_print " "
fi

# function
file_check_system() {
for NAMES in $NAME; do
  if [ "$IS64BIT" == true ]; then
    FILE=$SYSTEM/lib64/$NAMES
    FILE2=$SYSTEM_EXT/lib64/$NAMES
    if [ -f $FILE ] || [ -f $FILE2 ]; then
      ui_print "- Detected $NAMES 64"
      ui_print " "
      rm -f $MODPATH/system/lib64/$NAMES
    fi
  fi
  FILE=$SYSTEM/lib/$NAMES
  FILE2=$SYSTEM_EXT/lib/$NAMES
  if [ -f $FILE ] || [ -f $FILE2 ]; then
    ui_print "- Detected $NAMES"
    ui_print " "
    rm -f $MODPATH/system/lib/$NAMES
  fi
done
}
file_check_vendor() {
for NAMES in $NAME; do
  if [ "$IS64BIT" == true ]; then
    FILE=$VENDOR/lib64/$NAMES
    FILE2=$ODM/lib64/$NAMES
    if [ -f $FILE ] || [ -f $FILE2 ]; then
      ui_print "- Detected $NAMES 64"
      ui_print " "
      rm -f $MODPATH/system/vendor/lib64/$NAMES
    fi
  fi
  FILE=$VENDOR/lib/$NAMES
  FILE2=$ODM/lib/$NAMES
  if [ -f $FILE ] || [ -f $FILE2 ]; then
    ui_print "- Detected $NAMES"
    ui_print " "
    rm -f $MODPATH/system/vendor/lib/$NAMES
  fi
done
}

# check
NAME=libaudio-resampler.so
file_check_system
NAME="libAlacSwDec.so libOmxAlacDec.so
      libOmxAlacDecSw.so libstagefright_soft_somcalacdec.so"
file_check_vendor
NAME="libstagefrightdolby.so
      libstagefright_soft_ddpdec.so
      libstagefright_soft_ac4dec.so"
if [ $DOLBY == true ]; then
  file_check_vendor
fi

# audio rotation
FILE=$MODPATH/service.sh
if [ "`grep_prop audio.rotation $OPTIONALS`" == 1 ]; then
  ui_print "- Enables ro.audio.monitorRotation=true"
  sed -i '1i\
resetprop ro.audio.monitorRotation true' $FILE
  ui_print " "
fi

# raw
FILE=$MODPATH/.aml.sh
if [ "`grep_prop disable.raw $OPTIONALS`" == 0 ]; then
  ui_print "- Not disables Ultra Low Latency playback (RAW)"
  ui_print " "
else
  sed -i 's/#u//g' $FILE
fi

# vendor_overlay
DIR=/product/vendor_overlay
if [ "`grep_prop fix.vendor_overlay $OPTIONALS`" == 1 ]\
&& [ $DOLBY == true ] && [ -d $DIR ]; then
  ui_print "- Fixing $DIR mount..."
  cp -rf $DIR/*/* $MODPATH/system/vendor
  ui_print " "
fi

# uninstaller
NAME=DolbyModuleUninstaller.zip
if [ $DOLBY == true ]; then
  cp -f $MODPATH/$NAME /sdcard
  ui_print "- Flash /sdcard/$NAME"
  ui_print "  via recovery only if you got bootloop"
  ui_print " "
fi
rm -f $MODPATH/$NAME

# run
. $MODPATH/copy.sh
. $MODPATH/.aml.sh

# unmount
if [ "$BOOTMODE" == true ] && [ ! "$MAGISKPATH" ]; then
  unmount_mirror
fi




















