#export ISO_PATH=/home/jooho/dev/OSE_REPO_ISO/rhel7u2_ose3u1_160320
export ISO_PATH=/home/jooho/dev/OSE_REPO_ISO/rhel7u1_ose3u1_151125

#Check architecture
c_arch=$1
valid=false
for arch in min mid max;
do
  if [[ $c_arch == $arch ]]; then
     valid=true 
  fi
done
if [[ z$c_arch ==  "z" ]]  || [[ $valid != "true" ]]  ; then
  echo "usage : ./full_set_up_with_kvm.sh max (mid,min)"
  echo "or"
  echo "usage : ./full_set_up_with_kvm.sh max (mid,min) ose-smart-start.yaml"
  echo " \$1 : architecture "
  echo " \$2 : template  (must be under rhep-tools/ose_kvm_provision/template and looks like
  ose-smart-start,yaml.template) "
  exit 1
fi

# Check if specific template exist
if [[ z$2 != z ]]
then
  c_template=$2
  file_exist=$(ls rhep-tools/ose_kvm_provision/template/${c_template}.template)
  echo $?
  if [[ $? == 1 ]] ;then
    exit 1
  fi
fi


# Check if generating public key is needed
echo -e "Do you want to go through from the beginning?(y/n) (or start from copying public key)"
read need_populating_kvm_vm

if [ $need_populating_kvm_vm  == "y" ];
 then
    if [[ -e ./ansible-ose3-install ]]; then
      echo "* ansible-ose3-install is already cloned so I will pull it"
      cd ./ansible-ose3-install; git pull; cd ..
    else
      echo "* ansible-ose3-install is not here so I will clone it"
      git clone https://github.com/Jooho/ansible-ose3-install
    fi  
   
    ls $PWD/rhep-tools
    if [[ -e ./rhep-tools ]]; then
      echo "* rhep-tools is already cloned so I will pull it"
      cd ./rhep-tools; git pull; cd .. 
    else
      echo "* rhep-tools is not there so I will clone it"
      git clone https://github.com/Jooho/rhep-tools
    fi
   
    cp ansible-ose3-install/shell/setup.sh .
   
   
   
    #Create KVM VMs according to architecture
    cd ./rhep-tools/ose_kvm_provision/
    if [[ z$c_template == z ]]; then
       ./ose_kvm_provision.sh -mode=clone -arch=$c_arch
    else
       ./ose_kvm_provision.sh -mode=clone -arch=$c_arch -template=$c_template
    fi 

    echo Please wait to be stable...
    for i in {40..1}; 
    do
      echo -n "${i}.. "
      sleep 1
    done
    echo "OK MOVE ON"
    #sleep 40
    rm -rf ./*.txt
    rm -rf ./*yaml
     if [[ z$c_template == z ]]; then
      ./ose_kvm_provision.sh -mode=info -arch=$c_arch
      ./ose_kvm_provision.sh -mode=template -arch=$c_arch
    else
      ./ose_kvm_provision.sh -mode=info -arch=$c_arch -template=$c_template
      ./ose_kvm_provision.sh -mode=template -arch=$c_arch -template=$c_template
    fi 
   
    # Copy inventory file & ip information txt file.
    cd ../../
    cp ./rhep-tools/ose_kvm_provision/*.yaml .
    cp ./rhep-tools/ose_kvm_provision/*.txt .
   
    #Copy ISO files to master1 server 
    cp -R $ISO_PATH/* .
   
    #Clean up known_host(delete IPs start with 192.168.124.200)
    mv ~/.ssh/known_hosts  ~/.ssh/known_hosts_$(date +%Y%m%d%H%M%S)    #backup
    sed '/^192\.168\.124\|200/d' ~/.ssh/known_hosts > ~/.ssh/known_hosts

  fi

    master_ip=$(grep MASTER1_PRIVATE_IP ./ose31_kvm_info.txt|cut -d"=" -f2)
    echo -e "Type password for root of vm(redhat): \c"
    read password
    echo "sshpass -p $password ssh -q root@$master_ip 'mkdir -p /root/ose'"
    sshpass -p $password ssh -o StrictHostKeyChecking=no -q root@$master_ip 'mkdir -p /root/ose'
   
    for file in ./*; do
    #if ([ -f $file ] && [ ${file##*.} != "sh" ]); then
     if [[ -f $file ]]; then
        echo sshpass -p $password scp $(basename $file) root@$master_ip:/root/ose/.
        sshpass -p $password scp -o StrictHostKeyChecking=no $(basename $file) root@$master_ip:/root/ose/.
      fi
    done
    echo ""
    echo ""
    echo "NEXT STEP:"
    echo "After you connect to master server, go to ose folder then execute setup.sh"
    echo "cd ose;./setup.sh $(ls ./ |grep *.yaml)"
    echo ""
    echo "Now it is connecting to master1 server"
    ssh root@$master_ip
