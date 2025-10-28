#!/usr/bin/sh
# https://docs.aws.amazon.com/lambda/latest/dg/python-package.html#python-package-create-package-with-dependency
rm -rf package
python3.13 -m pip install --target ./package -r requirements.txt

(cd package && zip -r - .) > deployment_package.zip
zip -g deployment_package.zip lambda_function.py
