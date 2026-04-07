DROP DATABASE IF EXISTS demo_ventas_esmx CASCADE;
CREATE DATABASE demo_ventas_esmx;
USE demo_ventas_esmx;

CREATE TABLE clientes (
  cliente_id INT,
  nombre_cliente STRING,
  ciudad STRING,
  estado STRING,
  segmento STRING
) ROW FORMAT DELIMITED
FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE;

CREATE TABLE categorias (
  categoria_id INT,
  nombre_categoria STRING
) ROW FORMAT DELIMITED
FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE;

CREATE TABLE productos (
  producto_id INT,
  categoria_id INT,
  nombre_producto STRING,
  precio_unitario DECIMAL(10,2),
  indicador_activo STRING
) ROW FORMAT DELIMITED
FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE;

CREATE TABLE pedidos (
  pedido_id INT,
  cliente_id INT,
  fecha_pedido TIMESTAMP,
  estado_pedido STRING,
  canal_venta STRING
) ROW FORMAT DELIMITED
FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE;

CREATE TABLE partidas_pedido (
  partida_pedido_id INT,
  pedido_id INT,
  producto_id INT,
  cantidad INT,
  precio_unitario DECIMAL(10,2),
  monto_descuento DECIMAL(10,2)
) ROW FORMAT DELIMITED
FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE;

LOAD DATA LOCAL INPATH '/datasets/demo_ventas_esmx/clientes.tsv' OVERWRITE INTO TABLE clientes;
LOAD DATA LOCAL INPATH '/datasets/demo_ventas_esmx/categorias.tsv' OVERWRITE INTO TABLE categorias;
LOAD DATA LOCAL INPATH '/datasets/demo_ventas_esmx/productos.tsv' OVERWRITE INTO TABLE productos;
LOAD DATA LOCAL INPATH '/datasets/demo_ventas_esmx/pedidos.tsv' OVERWRITE INTO TABLE pedidos;
LOAD DATA LOCAL INPATH '/datasets/demo_ventas_esmx/partidas_pedido.tsv' OVERWRITE INTO TABLE partidas_pedido;
