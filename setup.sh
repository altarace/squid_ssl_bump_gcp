#install docker if needed
#sudo curl -fsSL https://get.docker.com/ | sh
#sudo usermod -aG docker $USER
#newgrp docker

#install gcloud if needed
#curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/google-cloud-sdk.tar.gz
#tar zxvf google-cloud-sdk.tar.gz
#./google-cloud-sdk/install.sh
#gcloud init

sudo apt install gettext

gcloud auth login
export GOOGLE_PROJECT_ID=`gcloud config get-value core/project`
export GOOGLE_PROJECT_NUMBER=`gcloud projects describe $GOOGLE_PROJECT_ID --format="value(projectNumber)"`
export BUCKET_SRC=$GOOGLE_PROJECT_ID-squid-conf
export REGION=us-central1
export ZONE=us-central1-a
export SVC_ACCT=squid-svc-account
export GCE_SERVICE_ACCOUNT=$SVC_ACCT\@$GOOGLE_PROJECT_ID.iam.gserviceaccount.com
export STARTUP_SCRIPT=startupsquid.sh
export NETNAME=custom-network2
export SECRET_NAME=squidkey
export RANGE=192.168.1.0/24
export PREFIX=`echo $RANGE|cut -c1-3`
export NAT_ROUTER=squid-nat-router
export NAT_IP=squid-natip
export NAT_CONF=squid-nat-config
export TEMPLATE_NAME=squid-template-1
export PROXY_TAG=squidproxy
export VDI_TAG=bastionvm
export ILB_HC=tcp-3128
export IG_NAME=squid-central1-ig
export INSTANCE_GROUP=squid-central1-ig
export BACKEND=squid-backend-service
export ILB_NAME=squid-ilb-central1

gsutil mb gs://$BUCKET_SRC
gcloud services enable oslogin.googleapis.com iap.googleapis.com secretmanager.googleapis.com
docker build -t docker_tmp .
docker cp `docker create docker_tmp`:/apps/squid .
tar cvf squid.tar squid/
gsutil cp squid.tar gs://$BUCKET_SRC/
#rm -rf squid.tar squid/
cd data/
gsutil cp  -r . gs://$BUCKET_SRC/data/
#gsutil ls gs://$BUCKET_SRC/
cd ..
export squid_key=`cat keys/CA_key.pem`
#echo $squid_key
echo -n $squid_key | gcloud beta secrets create $SECRET_NAME --replication-policy=automatic --data-file=-
gcloud iam service-accounts create $SVC_ACCT --display-name "GCE Service Account"
#gcloud iam service-accounts describe  $GCE_SERVICE_ACCOUNT

gcloud iam service-accounts add-iam-policy-binding $GCE_SERVICE_ACCOUNT --member=serviceAccount:$GCE_SERVICE_ACCOUNT --role=roles/iam.serviceAccountUser
gcloud beta secrets add-iam-policy-binding $SECRET_NAME --member=serviceAccount:$GCE_SERVICE_ACCOUNT --role=roles/secretmanager.secretAccessor

gsutil iam ch serviceAccount:$GCE_SERVICE_ACCOUNT:objectViewer gs://$BUCKET_SRC

gcloud projects add-iam-policy-binding $GOOGLE_PROJECT_ID     --member=serviceAccount:$GCE_SERVICE_ACCOUNT    --role=roles/monitoring.metricWriter
gcloud projects add-iam-policy-binding $GOOGLE_PROJECT_ID     --member=serviceAccount:$GCE_SERVICE_ACCOUNT    --role=roles/logging.logWriter

gcloud compute networks create $NETNAME --subnet-mode custom
gcloud compute networks subnets create subnet-$REGION\-$PREFIX  --network $NETNAME --region $REGION --range $RANGE

gcloud compute routers create $NAT_ROUTER  --network $NETNAME  --region  $REGION 
gcloud compute addresses create $NAT_IP --region $REGION --ip-version IPV4
#export NATIP=gcloud compute addresses describe $NAT_IP --region $REGION --format="value(address)"
gcloud compute routers nats create $NAT_CONF --router=$NAT_ROUTER --nat-external-ip-pool=$NAT_IP --nat-custom-subnet-ip-ranges=subnet-$REGION\-$PREFIX  --region  $REGION 

envsubst <startup.sh >$STARTUP_SCRIPT

gcloud compute instance-templates create $TEMPLATE_NAME --no-address --metadata=enable-oslogin=FALSE --service-account=$GCE_SERVICE_ACCOUNT --scopes=cloud-platform \
--machine-type g1-small --tags $PROXY_TAG  --network $NETNAME --image-family=debian-9  --image-project=debian-cloud --subnet=subnet-$REGION\-$PREFIX --region $REGION \
--metadata-from-file startup-script=$STARTUP_SCRIPT
gcloud compute  firewall-rules create $PROXY_TAG\-rules-squid-allow-hc  --priority=1000 --network $NETNAME  --allow=tcp:3128 --source-ranges=130.211.0.0/22,35.191.0.0/16  --target-tags=$PROXY_TAG 

gcloud compute firewall-rules create $PROXY_TAG\-allow-squid --direction=INGRESS --priority=1000 --network=$NETNAME --action=ALLOW --rules=tcp:3128 --target-tags=$PROXY_TAG

gcloud compute firewall-rules create $VDI_TAG\-deny-egress --direction=EGRESS --priority=1200 --network=$NETNAME --action=DENY --rules=all --target-tags=$VDI_TAG

gcloud compute firewall-rules create $PROXY_TAG\-allow-https-egress --direction=EGRESS --priority=1000 --network=$NETNAME --action=ALLOW --rules=tcp:443 --target-tags=$PROXY_TAG

gcloud compute health-checks create tcp $ILB_HC \
    --check-interval=5s \
    --timeout=5s \
    --healthy-threshold=2 \
    --unhealthy-threshold=2 \
    --port=3128

gcloud compute instance-groups managed create  $INSTANCE_GROUP  --base-instance-name $PROXY_TAG --template=$TEMPLATE_NAME --size=1 --zone=$ZONE

gcloud compute instance-groups managed set-autoscaling $INSTANCE_GROUP \
    --max-num-replicas 1 \
    --target-load-balancing-utilization 0.6 \
    --cool-down-period 90 --zone=$ZONE 

gcloud compute backend-services create $BACKEND --load-balancing-scheme=internal --protocol TCP --health-checks $ILB_HC --region $REGION

gcloud compute backend-services add-backend $BACKEND --instance-group $INSTANCE_GROUP --instance-group-zone $ZONE --region $REGION

gcloud compute forwarding-rules create $ILB_NAME \
    --region=$REGION \
    --load-balancing-scheme=internal \
    --ip-protocol=TCP \
    --ports=3128  --network $NETNAME \
    --backend-service=$BACKEND --subnet=subnet-$REGION\-$PREFIX \
    --backend-service-region=$REGION

export ILB_IP=`gcloud compute forwarding-rules describe $ILB_NAME --region $REGION --format="value(IPAddress)"`

gcloud compute firewall-rules create $VDI_TAG\-allow-to-ilb --direction=EGRESS --priority=1100 --network=$NETNAME --action=ALLOW --destination-ranges=$ILB_IP --rules=tcp:443 --target-tags=$VDI_TAG


