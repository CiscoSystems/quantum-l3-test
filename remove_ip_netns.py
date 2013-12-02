#!/usr/bin/python
#--------------------------------------------------------------
# Script to remove ip namespaces on an Openstack node
#
#--------------------------------------------------------------

import sys
from time import sleep
import subprocess

def remove_ip_ns():

    # List for the parsed namespaces
    ip_netns_list = []

    try:
        cmd_out = subprocess.check_output( "ip netns", shell=True, stderr=subprocess.STDOUT )
        print "ip netns\n%s\n" % cmd_out 
    except subprocess.CalledProcessError as err:
        print "Something went wrong! \nreturncode - '%s'\ncmd - '%s'\noutput - %s" % ( err.returncode, err.cmd, err.output )
        sys.exit(1)

    if cmd_out == '':
	print "No namespaces to delete"
	sys.exit(1)

    # Parse the ip netns output and delete the namespaces
    cmd_out = cmd_out.strip('\n')
    for ns in cmd_out.split('\n'):
       
	ns_cmd = "ip netns delete %s" % ns

	try:
	    print "Deleting namespace %s" % ns
            ns_out = subprocess.check_output( ns_cmd, shell=True, stderr=subprocess.STDOUT )
          
    	except subprocess.CalledProcessError as err:
            print "Something went wrong! \nreturncode - '%s'\ncmd - '%s'\noutput - %s" % ( err.returncode, err.cmd, err.output )
            sys.exit(1)



if __name__ == '__main__':

    remove_ip_ns()
