echo "******************************************************************************"
echo " Create a listener.ora file if it doesn't already exist." `date`
echo "******************************************************************************"
if [ ! -f ${ORACLE_HOME}/network/admin/listener.ora ]; then
echo "LISTENER =
(DESCRIPTION_LIST =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1))
    (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521))
  )
)
USE_SID_AS_SERVICE_listener=on
" > ${ORACLE_HOME}/network/admin/listener.ora
fi


echo "******************************************************************************"
echo "Check if database already exists." `date`
echo "******************************************************************************"
if [ ! -d ${DATA_DIR}/${ORACLE_SID^^} ]; then

  echo "******************************************************************************"
  echo "The database files don't exist, so create a new database." `date`
  echo "******************************************************************************"
  lsnrctl start

  dbca -silent -createDatabase                                                 \
    -templateName General_Purpose.dbc                                          \
    -gdbname ${ORACLE_SID} -sid ${ORACLE_SID} -responseFile NO_VALUE           \
    -characterSet AL32UTF8                                                     \
    -sysPassword ${SYS_PASSWORD}                                               \
    -systemPassword ${SYS_PASSWORD}                                            \
    -createAsContainerDatabase true                                            \
    -numberOfPDBs 1                                                            \
    -pdbName ${PDB_NAME}                                                       \
    -pdbAdminPassword ${PDB_PASSWORD}                                          \
    -databaseType MULTIPURPOSE                                                 \
    -automaticMemoryManagement false                                           \
    -totalMemory 1536                                                          \
    -storageType FS                                                            \
    -datafileDestination "${DATA_DIR}"                                         \
    -redoLogFileSize 50                                                        \
    -emConfiguration NONE                                                      \
    -ignorePreReqs

  echo "******************************************************************************"
  echo "Set the PDB to auto-start." `date`
  echo "******************************************************************************"
  sqlplus / as sysdba <<EOF
alter system set db_create_file_dest='${DATA_DIR}';
alter pluggable database ${PDB_NAME} save state;
alter system set local_listener='localhost';
exit;
EOF


  echo "******************************************************************************"
  echo "Flip the auto-start flag." `date`
  echo "******************************************************************************"
  cp /etc/oratab /tmp
  sed -i -e "s|${ORACLE_SID}:${ORACLE_HOME}:N|${ORACLE_SID}:${ORACLE_HOME}:Y|g" /tmp/oratab
  cp -f /tmp/oratab /etc/oratab


  echo "******************************************************************************"
  echo " Unzip APEX software." `date`
  echo "******************************************************************************"
  cd ${SOFTWARE_DIR}
  unzip ${APEX_SOFTWARE}
  cd apex


  echo "******************************************************************************"
  echo "Install APEX." `date`
  echo "******************************************************************************"
  sqlplus / as sysdba <<EOF
alter session set container = ${PDB_NAME};
create tablespace apex datafile size 1m autoextend on next 1m;
@apexins.sql APEX APEX TEMP /i/
BEGIN
    APEX_UTIL.set_security_group_id( 10 );

    APEX_UTIL.create_user(
        p_user_name       => 'ADMIN',
        p_email_address   => '${APEX_EMAIL}',
        p_web_password    => '${APEX_PASSWORD}',
        p_developer_privs => 'ADMIN' );

    APEX_UTIL.set_security_group_id( null );
    COMMIT;
END;
/
@apex_rest_config.sql ${APEX_PASSWORD} ${APEX_PASSWORD}
@apex_epg_config.sql ${ORACLE_HOME}
alter user APEX_PUBLIC_USER identified by ${APEX_PASSWORD} account unlock;
exit;
EOF

fi
