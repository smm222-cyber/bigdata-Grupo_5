#!/bin/bash
# Prueba funcional de HDFS: crear directorio, cargar archivo y consultarlo
hdfs dfs -mkdir -p /user/prueba
echo "hola bigdata" > prueba.txt
hdfs dfs -put -f prueba.txt /user/prueba/
hdfs dfs -ls /user/prueba
hdfs dfs -cat /user/prueba/prueba.txt