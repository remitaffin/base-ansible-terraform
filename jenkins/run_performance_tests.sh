#!/bin/bash

set -e

sh /usr/local/bin/apache-jmeter-2.13/bin/jmeter.sh \
	-Jjmeter.save.saveservice.output_format=xml \
    -n \
    -t jmeter-app.jmx \
    -l results.jtl
