This is a remix of Sal's  salrashid123/squid_ssl_bump_gcp project. This version will not do deep inspection, rather allow access to a particular project's GCP cloud console, with the intent of blocking access to all other projects. 
The squid allowed.urls and allowed.post.urls should be reviewed to confirm the needed GCP services URLs are enabled.
The target VM's (like the test VM being launched by the setup.sh script) will only have egress access through the squid proxy. 

Usage:
<br>update namespace in setup.sh (optional)
<br>authenticate with gcloud
<br>run setup.sh
