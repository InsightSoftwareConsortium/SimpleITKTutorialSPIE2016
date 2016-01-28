FROM insighttoolkit/simpleitk-notebooks:latest
MAINTAINER Insight Software Consortium <community@itk.org>

ADD README.rst ./
ADD "*.ipynb" ./
ADD downloaddata.py ./
ADD Data ./Data
RUN sudo chown -R jovyan.jovyan ./*
