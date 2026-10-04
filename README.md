# bigdata-Grupo_5
 
**LG14 – Investigación y despliegue de un repositorio Big Data con Docker**
Universidad del Valle · Tecnologías Emergentes
 
## Integrantes
- Monserrat Salazar Moring
- Nayara Kate Hurtado Barja
- Liz Gabriela Candia Escobar
 
## 1. Repositorio seleccionado
 
| Dato | Valor |
|---|---|
| Repositorio | hadoop-docker |
| URL | https://github.com/crs4/hadoop-docker |
| Autor / organización | CRS4 |
| Licencia | Apache-2.0 |
| Descripción | Imágenes Docker de Apache Hadoop (HDFS, YARN y MapReduce), una por servicio, con archivos Docker Compose para levantar un cluster pequeño. |
 
Elegimos este repositorio porque es de Hadoop, usa Docker y Docker Compose, tiene archivos de configuración propios y permite hacer una prueba funcional de HDFS sin necesitar demasiados recursos del equipo.
 
El análisis detallado (tecnologías, contenedores, puertos, redes, volúmenes, variables y limitaciones) está en [`docs/analisis.md`](docs/analisis.md).
 
## 2. Arquitectura
 
Desplegamos el compose de HDFS (`docker-compose-hdfs.yml`), que tiene 3 contenedores:
 
| Contenedor | Imagen | Función |
|---|---|---|
| namenode | `crs4/namenode:3.2.1` | Guarda los metadatos de HDFS: qué archivos existen y en qué bloques están |
| datanode | `crs4/datanode:3.2.1` | Guarda los bloques de datos |
| client | `crs4/hadoopclient:3.2.1` | Contenedor desde el que ejecutamos los comandos `hdfs dfs` |
 
![Diagrama de arquitectura](docs/diagrama-arquitectura.png)
 
Puntos importantes:
- Los tres contenedores se conectan a la red `bridge` que Docker Compose crea por defecto y se encuentran por nombre (`namenode`).
- El compose **no define volúmenes**, por lo que los datos de HDFS se pierden al ejecutar `docker compose down`.
- Todas las imágenes salen de una misma imagen base (`crs4/hadoop-base`, con Ubuntu 20.04, Java 8 y Hadoop 3.2.1), y una sola receta `Dockerfile` genera cada servicio según el argumento `cmd`.
- El repositorio también trae un compose completo con ResourceManager, NodeManager y HistoryServer (YARN y MapReduce). No lo usamos para mantener el consumo de recursos bajo.
 
## 3. Requisitos
- Docker Desktop (con Docker Compose v2) en funcionamiento.
- Git.
- Unos 4 GB de RAM libres para Docker (valor aproximado).
 
## 4. Instalación y ejecución
 
### Paso 1. Clonar el repositorio original
```bash
git clone https://github.com/crs4/hadoop-docker
cd hadoop-docker
```
 
### Paso 2. Identificar los archivos principales
```bash
ls -la
```
![ls -la](evidencias/00-ls-la.png)
 
### Paso 3. Analizar el compose
```bash
cat docker-compose-hdfs.yml
```
![Compose HDFS](evidencias/01-compose-hdfs.png)
 
Usamos una copia de este archivo en la raíz de nuestro repositorio. Le quitamos la línea `version: "3"`, porque Docker Compose v2 la considera obsoleta y solo muestra una advertencia.
 
### Paso 4. Construir o descargar las imágenes y ejecutar
Para descargar las imágenes publicadas y levantar el cluster:
```bash
docker compose -f docker-compose-hdfs.yml pull
docker compose -f docker-compose-hdfs.yml up -d
```
Si las imágenes no estuvieran disponibles, se construyen con el script del repositorio (copia en `scripts/build.sh`):
```bash
export HADOOP_VERSION=3.2.1
bash build.sh
```
 
### Paso 5. Verificar los contenedores
```bash
docker ps
```
Se ven los tres contenedores (namenode, datanode y client) en estado `Up`.
 
![docker ps](evidencias/03-docker-ps.png)
 
### Paso 6. Verificar que el datanode se registró
```bash
docker compose -f docker-compose-hdfs.yml exec client hdfs dfsadmin -report
```
El reporte indica un datanode activo (Live datanodes: 1).
 
![dfsadmin report](evidencias/04-dfsadmin-report.png)
 
## 5. Prueba funcional (HDFS)
 
La prueba consiste en crear un directorio, cargar un archivo y consultarlo. El script está en [`scripts/prueba-hdfs.sh`](scripts/prueba-hdfs.sh).
 
```bash
docker compose -f docker-compose-hdfs.yml exec client bash
hdfs dfs -mkdir -p /user/prueba
echo "hola bigdata" > prueba.txt
hdfs dfs -put -f prueba.txt /user/prueba/
hdfs dfs -ls /user/prueba
hdfs dfs -cat /user/prueba/prueba.txt
```
 
| Acción | Comando | Resultado |
|---|---|---|
| Crear directorio | `hdfs dfs -mkdir -p /user/prueba` | Se crea sin errores |
| Cargar archivo | `hdfs dfs -put -f prueba.txt /user/prueba/` | El archivo sube a HDFS |
| Consultar archivo | `hdfs dfs -ls /user/prueba` | `Found 1 items`: `prueba.txt`, 13 bytes |
| Leer contenido | `hdfs dfs -cat /user/prueba/prueba.txt` | Muestra `hola bigdata` |
 
![Prueba HDFS](evidencias/05-prueba-hdfs.png)
 
El resultado también está guardado como texto en [`evidencias/prueba-hdfs.txt`](evidencias/prueba-hdfs.txt).
 
### Verificación desde la interfaz web del NameNode
Con el cluster activo, entramos a http://localhost:9870. En la página principal se ve un nodo activo y, en *Utilities → Browse the file system*, el archivo dentro de `/user/prueba`.
 
![NameNode web](evidencias/06-namenode-web.png)
 
![Archivo en HDFS](evidencias/07-browse-hdfs.png)
 
### Observaciones
- Los mensajes `SASL encryption trust check` que aparecen al subir y leer el archivo son informativos (nivel `INFO`): indican que el cliente y el datanode no están marcados como de confianza para cifrado, algo normal en un cluster de pruebas sin seguridad.
- En el listado, el número `1` junto a los permisos es el factor de replicación: hay una sola copia del bloque porque el cluster tiene un solo datanode.
- Compose mostró la advertencia `the attribute version is obsolete`; no afecta el funcionamiento.
 
### Apagar el cluster
```bash
docker compose -f docker-compose-hdfs.yml down
```
Como no hay volúmenes, esto elimina también los datos guardados en HDFS.
 
## 6. Comparación con docker-hadoop
 
Comparamos con [big-data-europe/docker-hadoop](https://github.com/big-data-europe/docker-hadoop). El objetivo es ver diferencias de arquitectura, tecnología y propósito, no decidir cuál es mejor.
 
| Característica | docker-hadoop | crs4/hadoop-docker (nuestro repositorio) |
|---|---|---|
| Tecnología principal | Hadoop | Hadoop |
| Docker | Sí | Sí |
| Docker Compose | Sí | Sí |
| Número de contenedores | 5 (namenode, datanode, resourcemanager, nodemanager, historyserver) | 3 en el compose HDFS que usamos (namenode, datanode, client); 6 en el compose completo |
| Almacenamiento distribuido | HDFS | HDFS |
| Procesamiento distribuido | YARN y MapReduce | YARN y MapReduce en el compose completo; en el de HDFS no se usa |
| Interfaces web | NameNode, DataNode, ResourceManager, NodeManager, HistoryServer | Las mismas, publicadas por puerto en cada servicio (NameNode 9870, DataNode 9864, etc.) |
| Persistencia | Define volúmenes para los datos | No define volúmenes: los datos se pierden con `down` |
| Configuración | Variables de entorno en un archivo `hadoop.env` | Variables en el compose y `.env`; configuración reemplazable con `HADOOP_CUSTOM_CONF_DIR` |
| Contenedor cliente | No incluye uno dedicado | Incluye un contenedor `client` para ejecutar comandos |
| Imágenes | Publicadas por su autor | Se pueden construir con `build.sh` desde una imagen base común, con una sola receta parametrizada |
| Versiones de Hadoop | Imágenes para versiones concretas | Permite elegir versión con `HADOOP_VERSION` (3.2.1 por defecto; también Hadoop 2) |
| Complejidad de instalación | Baja | Baja si las imágenes se descargan; media si hay que construirlas |
| Documentación | README breve con ejemplos | README breve, centrado en construcción y configuración |
| Mantenimiento | Sin cambios recientes | Sin cambios desde hace unos 6 años; hay una deuda técnica conocida con los scripts `*-daemon.sh` |
| Caso de uso | Cluster Hadoop de pruebas y aprendizaje | Imágenes Hadoop personalizables para pruebas y desarrollo |
 
**Diferencias principales**
- Ambos son entornos de pruebas de Hadoop sobre Docker Compose, con HDFS y YARN.
- docker-hadoop está pensado para levantar un cluster ya armado, con persistencia mediante volúmenes.
- crs4/hadoop-docker se centra en cómo se **construyen** las imágenes: una receta común, una imagen por servicio y configuración reemplazable. Por eso nos permitió elegir una parte del cluster (solo HDFS), aunque sin persistencia.
 
## 7. Limitaciones encontradas
- **Scripts deprecados:** `cmd/hadoop.sh` y `cmd/hdfs.sh` usan `hadoop-daemon.sh`, `yarn-daemon.sh` y `mr-jobhistory-daemon.sh`, obsoletos en Hadoop 3 aunque todavía funcionan en 3.2.x. Los servicios individuales que usamos no dependen de ellos.
- **Sin persistencia:** no hay volúmenes definidos.
- **Sin mantenimiento reciente:** el último cambio es de hace unos 6 años.
- **Sin control de arranque:** no hay `depends_on` ni healthchecks; el datanode puede tardar unos segundos en registrarse.
 
## 8. Estructura del repositorio
```
bigdata-Grupo_5/
├── README.md
├── docker-compose-hdfs.yml    compose usado en el despliegue
├── .env                       variables del repositorio original
├── scripts/
│   ├── build.sh               construcción de imágenes (del repositorio original)
│   └── prueba-hdfs.sh         prueba funcional de HDFS
├── docs/
│   ├── analisis.md            análisis detallado
│   └── diagrama-arquitectura.png
└── evidencias/                capturas y resultados de las pruebas
```
 
## 9. Conclusiones
- Pudimos desplegar un cluster HDFS de tres contenedores y comprobar su funcionamiento: creamos un directorio, cargamos un archivo y lo leímos.
- Entendimos que NameNode y DataNode cumplen funciones distintas: uno guarda metadatos y el otro los bloques de datos, mientras el cliente consulta a ambos.
- Una sola receta de Dockerfile con un argumento permite generar imágenes distintas para cada servicio, lo que reduce la duplicación.
- Sin volúmenes, los datos desaparecen al eliminar los contenedores, lo que muestra la importancia de la persistencia en un despliegue real.
 
## Referencias
- Repositorio analizado: https://github.com/crs4/hadoop-docker
- Repositorio de comparación: https://github.com/big-data-europe/docker-hadoop