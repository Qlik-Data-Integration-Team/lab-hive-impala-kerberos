DROP DATABASE IF EXISTS demo_vendas_ptbr CASCADE;
CREATE DATABASE demo_vendas_ptbr;
USE demo_vendas_ptbr;

CREATE TABLE clientes (
  cliente_id INT,
  nome_cliente STRING,
  cidade STRING,
  estado STRING,
  segmento STRING
) ROW FORMAT DELIMITED
FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE;

CREATE TABLE categorias (
  categoria_id INT,
  nome_categoria STRING
) ROW FORMAT DELIMITED
FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE;

CREATE TABLE produtos (
  produto_id INT,
  categoria_id INT,
  nome_produto STRING,
  preco_unitario DECIMAL(10,2),
  indicador_ativo STRING
) ROW FORMAT DELIMITED
FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE;

CREATE TABLE pedidos (
  pedido_id INT,
  cliente_id INT,
  data_pedido DATE,
  status_pedido STRING,
  canal_venda STRING
) ROW FORMAT DELIMITED
FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE;

CREATE TABLE itens_pedido (
  item_pedido_id INT,
  pedido_id INT,
  produto_id INT,
  quantidade INT,
  preco_unitario DECIMAL(10,2),
  valor_desconto DECIMAL(10,2)
) ROW FORMAT DELIMITED
FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE;

LOAD DATA LOCAL INPATH '/datasets/demo_vendas_ptbr/clientes.tsv' OVERWRITE INTO TABLE clientes;
LOAD DATA LOCAL INPATH '/datasets/demo_vendas_ptbr/categorias.tsv' OVERWRITE INTO TABLE categorias;
LOAD DATA LOCAL INPATH '/datasets/demo_vendas_ptbr/produtos.tsv' OVERWRITE INTO TABLE produtos;
LOAD DATA LOCAL INPATH '/datasets/demo_vendas_ptbr/pedidos.tsv' OVERWRITE INTO TABLE pedidos;
LOAD DATA LOCAL INPATH '/datasets/demo_vendas_ptbr/itens_pedido.tsv' OVERWRITE INTO TABLE itens_pedido;
