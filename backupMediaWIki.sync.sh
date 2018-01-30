#!/bin/bash
#set -x
 
# Titulo         : "backupMediaWIki.sync.sh"
# Descricao      : Este script sincroniza tarball gerado remotamente em servidor local.
# Autor          : Aecio Junior <aeciojr@gmail.com>
# Data           : 29 de Agosto de 2015.
# Versao         : 0.1
# Usage          : "backupMediaWIki.sync.sh"
# Requerimentos  : 1. Necessita de acesso SSH com a Wiki remota
#                  2. Necessita de relacao de confianca
#                  3. Necessita de script remoto para geracao de tarball
 
#set +x
 
MediaWiki_User="userssh"
MediaWiki_IP="192.168.105.172"
ScriptBackup="/home/$MediaWiki_User/BackupMediaWiki.sh"
DirBackupLocal="/var/backups/MediaWiki"
DirBackupRemoto="/var/backups/MediaWiki"
DirTemp="/tmp"
ArquivoLog="/var/log/`basename $0`.log"
MailList="aeciojr@gmail.com"
 
_DataHoraPrint(){ date "+%Y/%m/%d %H:%M:%S"; }
 
_Print(){
   local Flag="$( echo $1 | tr [:lower:] [:upper:])"
   echo -e "\n`_DataHoraPrint` [ $Flag ] $2 \n"
}
 
_ExecutaCmdRemoto(){
   local RC=0
   ssh ${MediaWiki_User}@${MediaWiki_IP} "$1" || local RC=$?
   return $RC
}
 
_ExecutaBackupRemoto(){
   local RC=0
   local ArquivoTmp=$( mktemp -p $DirTemp )
   _ExecutaCmdRemoto "sudo rm -rfv $DirBackupRemoto/*.gz"
   ssh ${MediaWiki_User}@${MediaWiki_IP} "$ScriptBackup" | tee $ArquivoTmp 2>&1 || local RC=$?
   if [ $RC -eq 0 ]; then
      local ArquivoLog=$( grep \@ "$ArquivoTmp" | cut -d\@ -f2 )
      local ComandoObterArquivoBkp="grep -E '>>>|<<<' $ArquivoLog | cut -d\@ -f2 | tail -n1"
      local ArquivoBkp=$( _ExecutaCmdRemoto "$ComandoObterArquivoBkp" )
      local ComandoObterHashMD5="md5sum $ArquivoBkp | awk '{ print $1 }'"
      local HashMD5=$( _ExecutaCmdRemoto "$ComandoObterHashMD5" | awk '{ print $1 }' )
      _Print SUCESSO "Geracao de tarball unico (app+bd) remoto"
      echo "HashMD5: $HashMD5"
      echo "ArquivoBkp: $ArquivoBkp"
   else
      echo Problemas com ssh
   fi
   [[ -f $ArquivoTmp ]] && rm -rf $ArquivoTmp > /dev/null
   return $RC
}
 
_RemanejaArquivo(){
   local RC=0
   local ArquivoBkp=$1
   local HashMD5remoto=$2
   local BaseName=$( basename $ArquivoBkp )
   local ArquivoDestino="${DirBackupLocal}/$BaseName"
   local ArquivoTmp=$( mktemp -p $DirTemp )
 
   [[ ! -d $DirBackupLocal ]] && mkdir -p $DirBackupLocal
   SegundosInicial="`date +%s`"
   scp ${MediaWiki_User}@${MediaWiki_IP}:$ArquivoBkp $DirBackupLocal || local RC=$?
   SegundosFinal="`date +%s`"
   ((SegundosTotal=$SegundosFinal-$SegundosInicial))
   TimeStampDuracao=$( _ConvertSegundos $SegundosTotal )
   Tamanho=$( du -sh $ArquivoDestino | cut -f1 )
 
   if [ $RC -eq 0 ]; then
      _Print SUCESSO "Copia local do arquivo remoto (scp reverso)"
      echo -e "\tDuracao: $TimeStampDuracao"
      echo -e "\tTamanho: $Tamanho"
      ## Origem.
      local Origem="${MediaWiki_User}@${MediaWiki_IP}:$ArquivoBkp"
      _Print INFO "Origem (remoto):\n\n\t[ $Origem ]"
 
      ## Destino.
      local BaseName=$( basename $ArquivoBkp )
      local EndIPLocal=$( ip a|grep -E 'inet.*eth0'|awk '{ print $2 }' | cut -d \/ -f1 )
      local Destino="`whoami`@${EndIPLocal}:$ArquivoDestino"
      _Print INFO "Destino (local):\n\n\t[ $Destino ]"
 
      ## MD5Sum
      local ArquivoLocal="${DirBackupLocal}/$( basename $ArquivoBkp )"
      md5sum $ArquivoLocal > $ArquivoTmp 2>&1 || local RC=$?
      if [ $RC -eq 0 ]; then
         local HashMD5Local=$( awk '{ print $1 }' < $ArquivoTmp )
         if [ ${HashMD5remoto} == ${HashMD5Local} ]; then
            _Print SUCESSO "Validacao de hash MD5"
            _Print INFO "Origem (remoto):\n\n\t[ ${HashMD5remoto} ]"
            _Print INFO "Destino (local):\n\n\t[ ${HashMD5Local} ]"
         else
            _Print WARN "Hash MD5 divergente (remoto x local)"
         fi
      else
         _Print WARN "Erro no calculo MD5"
      fi
   else
      _Print WARN "Erro no SCP"
   fi
   [[ -f $ArquivoTmp ]] && rm -rf $ArquivoTmp > /dev/null
   return $RC
}
 
_RemoveArquivoRemoto(){
   local RC=0
   local ArquivoBackup=$1
   ssh ${MediaWiki_User}@${MediaWiki_IP} "sudo rm -rfv $ArquivoBackup" || local RC=$?
   return $RC
}
 
_SendMail(){
   local RC=0
   local Comando="sudo mail -s \"Backup MediaWiki [] - Sincronização Local ( -> DEST )\" $MailList"
   cat $ArquivoLog | ssh ${MediaWiki_User}@${MediaWiki_IP} "$Comando" || local RC=$?
   return $RC
}
 
_ConvertSegundos(){
   Segundos=$1
   ((sec=Segundos%60, Segundos/=60, min=Segundos%60, hrs=Segundos/60))
   Timestamp=$(printf "%d:%02d:%02d" $hrs $min $sec)
   echo $Timestamp
}
 
#--- Inicio do Script ---#
 
RC=0
 
{
ArquivoTmp=$( mktemp -p $DirTemp )
 
_Print INFO "Iniciado JobGracaoDeTarball (app+bd)..."
_ExecutaBackupRemoto > $ArquivoTmp #|| RC=0
_Print INFO "Concluido JobGracaoDeTarball (app+bd)..."
 
echo "#---- Inicio - Sincronizacao local ( >> DEST ) ----#"
 
if [ $RC -eq 0 ]; then
   ArquivoRemanejar=$( grep ^ArquivoBkp $ArquivoTmp | cut -d\: -f2 )
   HashArquivoRemanejar=$( grep ^HashMD5 $ArquivoTmp | cut -d\: -f2 )
   #SegundosInicial="`date +%s`"
   _RemanejaArquivo $ArquivoRemanejar $HashArquivoRemanejar || RC=$?
   #SegundosFinal="`date +%s`"
   #((SegundosTotal=$SegundosInicial-$SegundosFinal))
   #TimeStampDuracao=$( _ConvertSegundos $SegundosTotal )
 
   if [ $RC -eq 0 ]; then
      echo "# ---- Fim - Sincronizacao ( DEST <- ) ----#"
   else
      _Print ERRO "Erro no remanejamento. Verifique a geracao do tarball unico"
   fi
else
   _Print ERRO "Erro no Backup remoto"
fi
} | tee "$ArquivoLog"
 
[[ $RC -eq 0 ]] && { _SendMail || RC=$RC; }
[[ -f $ArquivoTmp ]] && rm -rf $ArquivoTmp > /dev/null 2>&1
 
exit $RC
 
#--- Fim do Script ---#
