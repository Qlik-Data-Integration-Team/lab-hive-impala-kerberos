DROP DATABASE IF EXISTS demo_sales_en CASCADE;
CREATE DATABASE demo_sales_en;
USE demo_sales_en;

CREATE TABLE customers (
  customer_id INT,
  customer_name STRING,
  city_name STRING,
  state_code STRING,
  segment_name STRING
) ROW FORMAT DELIMITED
FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE;

CREATE TABLE categories (
  category_id INT,
  category_name STRING
) ROW FORMAT DELIMITED
FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE;

CREATE TABLE products (
  product_id INT,
  category_id INT,
  product_name STRING,
  unit_price DECIMAL(10,2),
  active_flag STRING
) ROW FORMAT DELIMITED
FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE;

CREATE TABLE orders (
  order_id INT,
  customer_id INT,
  order_date DATE,
  order_status STRING,
  sales_channel STRING
) ROW FORMAT DELIMITED
FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE;

CREATE TABLE order_items (
  order_item_id INT,
  order_id INT,
  product_id INT,
  quantity INT,
  unit_price DECIMAL(10,2),
  discount_amount DECIMAL(10,2)
) ROW FORMAT DELIMITED
FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE;

LOAD DATA LOCAL INPATH '/datasets/demo_sales_en/customers.tsv' OVERWRITE INTO TABLE customers;
LOAD DATA LOCAL INPATH '/datasets/demo_sales_en/categories.tsv' OVERWRITE INTO TABLE categories;
LOAD DATA LOCAL INPATH '/datasets/demo_sales_en/products.tsv' OVERWRITE INTO TABLE products;
LOAD DATA LOCAL INPATH '/datasets/demo_sales_en/orders.tsv' OVERWRITE INTO TABLE orders;
LOAD DATA LOCAL INPATH '/datasets/demo_sales_en/order_items.tsv' OVERWRITE INTO TABLE order_items;
