/* =========================================================
   PROYECTO: ANALISIS INTELIGENTE DE VENTAS Y CLIENTES
   TECNOLOGIAS: SQL SERVER + PYTHON
   OBJETIVO:
   Construcción de modelo relacional y consultas orientadas
   a Business Intelligence y análisis estratégico.
========================================================= */

------------------------------------------------------------
-- 1. CREACION DE BASE DE DATOS
------------------------------------------------------------

CREATE DATABASE Proyecto_Ventas_Inteligente;
GO

USE Proyecto_Ventas_Inteligente;
GO


/* =========================================================
   2. LIMPIEZA Y PREPARACION DE DATOS
========================================================= */

------------------------------------------------------------
-- Reemplazar CustomerID nulos por 0
------------------------------------------------------------

UPDATE ventas_principales
SET customerid = 0
WHERE customerid IS NULL;

------------------------------------------------------------
-- Verificar registros actualizados
------------------------------------------------------------

SELECT TOP 10 *
FROM ventas_principales
WHERE customerid = 0;

------------------------------------------------------------
-- Visualizar dataset limpio
------------------------------------------------------------

SELECT *
FROM ventas_principales_clean;


------------------------------------------------------------
-- Crear columna TotalAmount
------------------------------------------------------------

ALTER TABLE ventas_principales_clean
ADD totalamount DECIMAL(10,2);

UPDATE ventas_principales_clean
SET totalamount = quantity * unitprice;

------------------------------------------------------------
-- Crear columna Mes
------------------------------------------------------------

ALTER TABLE ventas_principales_clean
ADD mes INT;

UPDATE ventas_principales_clean
SET mes = MONTH(invoicedate);

------------------------------------------------------------
-- Crear columna Año
------------------------------------------------------------

ALTER TABLE ventas_principales_clean
ADD anio INT;

UPDATE ventas_principales_clean
SET anio = YEAR(invoicedate);

------------------------------------------------------------
-- Validar ingresos totales
------------------------------------------------------------

SELECT
    SUM(totalamount) AS revenue_total
FROM ventas_principales_clean;


/* =========================================================
   3. CREACION DEL MODELO RELACIONAL
========================================================= */

------------------------------------------------------------
-- TABLA CLIENTES
------------------------------------------------------------

CREATE TABLE clientes (
    customerid INT PRIMARY KEY,
    country VARCHAR(100)
);

------------------------------------------------------------
-- TABLA PRODUCTOS
------------------------------------------------------------

CREATE TABLE productos (
    stockcode VARCHAR(50) PRIMARY KEY,
    description VARCHAR(255),
    unitprice DECIMAL(10,2)
);

------------------------------------------------------------
-- TABLA VENTAS
------------------------------------------------------------

CREATE TABLE ventas (
    id_venta INT IDENTITY(1,1) PRIMARY KEY,
    invoiceno VARCHAR(50),
    customerid INT,
    invoicedate DATETIME,
    totalamount DECIMAL(10,2),
    mes INT,
    anio INT
);

------------------------------------------------------------
-- TABLA DETALLE_VENTAS
------------------------------------------------------------

CREATE TABLE detalle_ventas (
    id_detalle INT IDENTITY(1,1) PRIMARY KEY,
    id_venta INT,
    stockcode VARCHAR(50),
    quantity INT,

    FOREIGN KEY (id_venta)
    REFERENCES ventas(id_venta),

    FOREIGN KEY (stockcode)
    REFERENCES productos(stockcode)
);


/* =========================================================
   4. CARGA DE DATOS AL MODELO RELACIONAL
========================================================= */

------------------------------------------------------------
-- INSERTAR CLIENTES
------------------------------------------------------------

INSERT INTO clientes (customerid, country)
SELECT
    customerid,
    MAX(country) AS country
FROM ventas_principales_clean
WHERE customerid <> 0
GROUP BY customerid;

------------------------------------------------------------
-- INSERTAR PRODUCTOS
------------------------------------------------------------

INSERT INTO productos (
    stockcode,
    description,
    unitprice
)
SELECT
    stockcode,
    MAX(description),
    MAX(unitprice)
FROM ventas_principales_clean
GROUP BY stockcode;

------------------------------------------------------------
-- INSERTAR VENTAS
------------------------------------------------------------

INSERT INTO ventas (
    invoiceno,
    customerid,
    invoicedate,
    totalamount,
    mes,
    anio
)
SELECT
    invoiceno,
    customerid,
    MAX(invoicedate),
    SUM(totalamount),
    MAX(mes),
    MAX(anio)
FROM ventas_principales_clean
WHERE customerid <> 0
GROUP BY invoiceno, customerid;

------------------------------------------------------------
-- INSERTAR DETALLE DE VENTAS
------------------------------------------------------------

INSERT INTO detalle_ventas (
    id_venta,
    stockcode,
    quantity
)
SELECT
    v.id_venta,
    vp.stockcode,
    vp.quantity
FROM ventas_principales_clean vp
JOIN ventas v
    ON vp.invoiceno = v.invoiceno
WHERE vp.customerid <> 0;


/* =========================================================
   5. VALIDACIONES DEL MODELO
========================================================= */

------------------------------------------------------------
-- Visualizar tablas creadas
------------------------------------------------------------

SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE';

------------------------------------------------------------
-- Ver columnas de ventas_principales_clean
------------------------------------------------------------

SELECT
    COLUMN_NAME,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'ventas_principales_clean';

------------------------------------------------------------
-- Ver columnas de detalle_ventas
------------------------------------------------------------

SELECT
    COLUMN_NAME,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'detalle_ventas';

------------------------------------------------------------
-- Ver registros de ventas
------------------------------------------------------------

SELECT TOP 10 *
FROM ventas;


/* =========================================================
   6. CREACION DE RELACION ENTRE CLIENTES Y VENTAS
========================================================= */

------------------------------------------------------------
-- Verificar clientes inexistentes
------------------------------------------------------------

SELECT DISTINCT customerid
FROM ventas
WHERE customerid NOT IN (
    SELECT customerid
    FROM clientes
);

------------------------------------------------------------
-- Insertar clientes faltantes
------------------------------------------------------------

INSERT INTO clientes (customerid)
SELECT DISTINCT customerid
FROM ventas
WHERE customerid NOT IN (
    SELECT customerid
    FROM clientes
);

------------------------------------------------------------
-- Crear Foreign Key
------------------------------------------------------------

ALTER TABLE ventas
ADD CONSTRAINT FK_ventas_clientes
FOREIGN KEY (customerid)
REFERENCES clientes(customerid);

------------------------------------------------------------
-- Verificar Foreign Key
------------------------------------------------------------

SELECT name
FROM sys.foreign_keys
WHERE name = 'FK_ventas_clientes';


/* =========================================================
   7. CONSULTAS DE NEGOCIO
========================================================= */

------------------------------------------------------------
-- 1. Ingreso total generado
------------------------------------------------------------

SELECT
    ROUND(SUM(totalamount),2) AS ingreso_total
FROM ventas;

------------------------------------------------------------
-- 2. Países con mayores ventas
------------------------------------------------------------

SELECT
    c.country,
    ROUND(SUM(v.totalamount),2) AS total_ventas
FROM ventas v
JOIN clientes c
    ON v.customerid = c.customerid
GROUP BY c.country
ORDER BY total_ventas DESC;

------------------------------------------------------------
-- 3. Productos más vendidos
------------------------------------------------------------

SELECT TOP 10
    p.description,
    SUM(dv.quantity) AS total_vendido
FROM detalle_ventas dv
JOIN productos p
    ON dv.stockcode = p.stockcode
WHERE p.description IS NOT NULL
AND p.description <> ''
AND p.description <> 'Sin descripción'
GROUP BY p.description
ORDER BY total_vendido DESC;

------------------------------------------------------------
-- 4. Productos más rentables
------------------------------------------------------------

SELECT TOP 10
    p.description,
    ROUND(SUM(dv.quantity * p.unitprice),2) AS ingresos
FROM detalle_ventas dv
JOIN productos p
    ON dv.stockcode = p.stockcode
WHERE p.description IS NOT NULL
AND p.description <> ''
AND p.description <> 'Sin descripción'
GROUP BY p.description
ORDER BY ingresos DESC;

------------------------------------------------------------
-- 5. Ticket promedio
------------------------------------------------------------

SELECT
    ROUND(AVG(totalamount),2) AS ticket_promedio
FROM ventas;

------------------------------------------------------------
-- 6. Clientes más valiosos
------------------------------------------------------------

SELECT TOP 10
    customerid,
    ROUND(SUM(totalamount),2) AS gasto_total
FROM ventas
GROUP BY customerid
ORDER BY gasto_total DESC;

------------------------------------------------------------
-- 7. Clientes más frecuentes
------------------------------------------------------------

SELECT TOP 10
    c.customerid,
    COUNT(v.invoiceno) AS frecuencia_compras
FROM ventas v
JOIN clientes c
    ON v.customerid = c.customerid
GROUP BY c.customerid
ORDER BY frecuencia_compras DESC;

------------------------------------------------------------
-- 8. Meses con mayores ventas
------------------------------------------------------------

SELECT
    mes,
    ROUND(SUM(totalamount),2) AS ventas_totales
FROM ventas
GROUP BY mes
ORDER BY ventas_totales DESC;

------------------------------------------------------------
-- 9. Estacionalidad de ventas
------------------------------------------------------------

SELECT
    anio,
    mes,
    ROUND(SUM(totalamount),2) AS ventas
FROM ventas
GROUP BY anio, mes
ORDER BY anio, mes;

------------------------------------------------------------
-- 10. Productos con más devoluciones
------------------------------------------------------------

SELECT TOP 10
    p.description,
    COUNT(*) AS devoluciones
FROM detalle_ventas dv
JOIN productos p
    ON dv.stockcode = p.stockcode
WHERE dv.quantity < 0
AND p.description IS NOT NULL
AND p.description <> ''
AND p.description <> 'Sin descripción'
GROUP BY p.description
ORDER BY devoluciones DESC;

------------------------------------------------------------
-- 11. Países con menor actividad comercial
------------------------------------------------------------

SELECT TOP 10
    c.country,
    ROUND(SUM(v.totalamount),2) AS ventas_totales
FROM ventas v
JOIN clientes c
    ON v.customerid = c.customerid
GROUP BY c.country
ORDER BY ventas_totales ASC;

------------------------------------------------------------
-- 12. Productos comprados juntos
------------------------------------------------------------

SELECT TOP 20
    p1.description AS producto_1,
    p2.description AS producto_2,
    COUNT(*) AS frecuencia
FROM detalle_ventas d1
JOIN detalle_ventas d2
    ON d1.id_venta = d2.id_venta
    AND d1.stockcode < d2.stockcode

JOIN productos p1
    ON d1.stockcode = p1.stockcode

JOIN productos p2
    ON d2.stockcode = p2.stockcode

WHERE p1.description IS NOT NULL
AND p1.description <> ''
AND p1.description <> 'Sin descripción'

AND p2.description IS NOT NULL
AND p2.description <> ''
AND p2.description <> 'Sin descripción'

GROUP BY p1.description, p2.description
ORDER BY frecuencia DESC;

------------------------------------------------------------
-- 13. Clientes que concentran ingresos
------------------------------------------------------------

SELECT TOP 20
    c.customerid,
    ROUND(SUM(v.totalamount),2) AS ingresos
FROM ventas v
JOIN clientes c
    ON v.customerid = c.customerid
GROUP BY c.customerid
ORDER BY ingresos DESC;

------------------------------------------------------------
-- 14. Clientes inactivos
------------------------------------------------------------

SELECT
    c.customerid,
    MAX(v.invoicedate) AS ultima_compra
FROM ventas v
JOIN clientes c
    ON v.customerid = c.customerid
GROUP BY c.customerid
ORDER BY ultima_compra ASC;

------------------------------------------------------------
-- 15. Clientes con mayor potencial comercial
------------------------------------------------------------

SELECT TOP 10
    customerid,
    COUNT(invoiceno) AS total_compras,
    ROUND(SUM(totalamount),2) AS ingresos_generados,
    ROUND(AVG(totalamount),2) AS ticket_promedio
FROM ventas
GROUP BY customerid
ORDER BY ingresos_generados DESC;


/* =========================================================
   8. KPIs ESTRATEGICOS
========================================================= */

------------------------------------------------------------
-- KPI 1: Ingreso total
------------------------------------------------------------

SELECT
    ROUND(SUM(totalamount),2) AS ingreso_total
FROM ventas;

------------------------------------------------------------
-- KPI 2: Total clientes
------------------------------------------------------------

SELECT
    COUNT(DISTINCT customerid) AS total_clientes
FROM clientes;

------------------------------------------------------------
-- KPI 3: Total transacciones
------------------------------------------------------------

SELECT
    COUNT(DISTINCT invoiceno) AS total_transacciones
FROM ventas;

------------------------------------------------------------
-- KPI 4: Producto más vendido
------------------------------------------------------------

SELECT TOP 1
    p.description,
    SUM(dv.quantity) AS total_vendido
FROM detalle_ventas dv
JOIN productos p
    ON dv.stockcode = p.stockcode
WHERE p.description IS NOT NULL
AND p.description <> ''
AND p.description <> 'Sin descripción'
GROUP BY p.description
ORDER BY total_vendido DESC;

------------------------------------------------------------
-- KPI 5: Producto más rentable
------------------------------------------------------------

SELECT TOP 1
    p.description,
    ROUND(SUM(dv.quantity * p.unitprice),2) AS ingresos
FROM detalle_ventas dv
JOIN productos p
    ON dv.stockcode = p.stockcode
WHERE p.description IS NOT NULL
AND p.description <> ''
AND p.description <> 'Sin descripción'
GROUP BY p.description
ORDER BY ingresos DESC;

------------------------------------------------------------
-- KPI 6: País con más ventas
------------------------------------------------------------

SELECT TOP 1
    c.country,
    ROUND(SUM(v.totalamount),2) AS ventas_totales
FROM ventas v
JOIN clientes c
    ON v.customerid = c.customerid
GROUP BY c.country
ORDER BY ventas_totales DESC;

------------------------------------------------------------
-- KPI 7: Cliente más valioso
------------------------------------------------------------

SELECT TOP 1
    customerid,
    ROUND(SUM(totalamount),2) AS gasto_total
FROM ventas
GROUP BY customerid
ORDER BY gasto_total DESC;

------------------------------------------------------------
-- KPI 8: Mes con más ventas
------------------------------------------------------------

SELECT TOP 1
    mes,
    ROUND(SUM(totalamount),2) AS ventas_totales
FROM ventas
GROUP BY mes
ORDER BY ventas_totales DESC;

------------------------------------------------------------
-- KPI 9: Tasa de devoluciones
------------------------------------------------------------

SELECT
    ROUND(
        (SUM(CASE WHEN quantity < 0 THEN 1 ELSE 0 END) * 100.0)
        / COUNT(*),
    2) AS tasa_devoluciones
FROM detalle_ventas;

------------------------------------------------------------
-- KPI 10: Clientes más frecuentes
------------------------------------------------------------

SELECT TOP 10
    customerid,
    COUNT(invoiceno) AS frecuencia_compras
FROM ventas
GROUP BY customerid
ORDER BY frecuencia_compras DESC;

------------------------------------------------------------
-- KPI 11: Promedio productos por compra
------------------------------------------------------------

SELECT
    ROUND(AVG(cantidad_productos),2) AS promedio_productos
FROM (
    SELECT
        id_venta,
        SUM(quantity) AS cantidad_productos
    FROM detalle_ventas
    GROUP BY id_venta
) AS resumen;

------------------------------------------------------------
-- KPI 12: Top mercados internacionales
------------------------------------------------------------

SELECT TOP 5
    c.country,
    ROUND(SUM(v.totalamount),2) AS ingresos
FROM ventas v
JOIN clientes c
    ON v.customerid = c.customerid
GROUP BY c.country
ORDER BY ingresos DESC;

------------------------------------------------------------
-- KPI 13: Productos diferentes vendidos
------------------------------------------------------------

SELECT
    COUNT(DISTINCT stockcode) AS productos_diferentes
FROM detalle_ventas;

------------------------------------------------------------
-- KPI 14: Clientes estratégicos
------------------------------------------------------------

SELECT TOP 10
    customerid,
    COUNT(invoiceno) AS total_compras,
    ROUND(SUM(totalamount),2) AS ingresos_generados,
    ROUND(AVG(totalamount),2) AS ticket_promedio
FROM ventas
GROUP BY customerid
ORDER BY ingresos_generados DESC;

------------------------------------------------------------
-- KPI 15: Ingreso Promedio por Cliente
------------------------------------------------------------

SELECT
    ROUND(AVG(gasto_cliente),2) AS ingreso_promedio_cliente
FROM (
    SELECT
        customerid,
        SUM(totalamount) AS gasto_cliente
    FROM ventas
    GROUP BY customerid
) AS resumen_clientes;


/* =========================================================
   9. CONSULTAS DE APOYO Y VALIDACION
========================================================= */

------------------------------------------------------------
-- Validar cantidad total de ventas
------------------------------------------------------------

SELECT
    COUNT(*) AS total_registros_ventas
FROM ventas;

------------------------------------------------------------
-- Validar cantidad total de clientes
------------------------------------------------------------

SELECT
    COUNT(*) AS total_clientes
FROM clientes;

------------------------------------------------------------
-- Validar cantidad total de productos
------------------------------------------------------------

SELECT
    COUNT(*) AS total_productos
FROM productos;

------------------------------------------------------------
-- Validar cantidad total de detalles de venta
------------------------------------------------------------

SELECT
    COUNT(*) AS total_detalle_ventas
FROM detalle_ventas;

------------------------------------------------------------
-- Verificar productos sin descripción
------------------------------------------------------------

SELECT *
FROM productos
WHERE description IS NULL
OR description = ''
OR description = 'Sin descripción';

------------------------------------------------------------
-- Verificar ventas con montos negativos
------------------------------------------------------------

SELECT *
FROM ventas
WHERE totalamount < 0;

------------------------------------------------------------
-- Verificar devoluciones
------------------------------------------------------------

SELECT *
FROM detalle_ventas
WHERE quantity < 0;


/* =========================================================
   10. OPTIMIZACION DEL MODELO RELACIONAL
========================================================= */

------------------------------------------------------------
-- Eliminar columna redundante country de ventas
------------------------------------------------------------

ALTER TABLE ventas
DROP COLUMN country;

------------------------------------------------------------
-- Crear índices para optimizar consultas
------------------------------------------------------------

CREATE INDEX idx_ventas_customerid
ON ventas(customerid);

CREATE INDEX idx_detalle_ventas_stockcode
ON detalle_ventas(stockcode);

CREATE INDEX idx_detalle_ventas_idventa
ON detalle_ventas(id_venta);

CREATE INDEX idx_ventas_fecha
ON ventas(invoicedate);

CREATE INDEX idx_ventas_mes_anio
ON ventas(mes, anio);


/* =========================================================
   11. CONSULTAS FINALES DE BUSINESS INTELLIGENCE
========================================================= */

------------------------------------------------------------
-- Top 5 clientes con mayor facturación
------------------------------------------------------------

SELECT TOP 5
    customerid,
    ROUND(SUM(totalamount),2) AS ingresos
FROM ventas
GROUP BY customerid
ORDER BY ingresos DESC;

------------------------------------------------------------
-- Top 5 productos más rentables
------------------------------------------------------------

SELECT TOP 5
    p.description,
    ROUND(SUM(dv.quantity * p.unitprice),2) AS ingresos
FROM detalle_ventas dv
JOIN productos p
    ON dv.stockcode = p.stockcode
WHERE p.description IS NOT NULL
AND p.description <> ''
AND p.description <> 'Sin descripción'
GROUP BY p.description
ORDER BY ingresos DESC;

------------------------------------------------------------
-- Evolución mensual de ventas
------------------------------------------------------------

SELECT
    anio,
    mes,
    ROUND(SUM(totalamount),2) AS ventas_totales
FROM ventas
GROUP BY anio, mes
ORDER BY anio, mes;

------------------------------------------------------------
-- Países con mayores ingresos
------------------------------------------------------------

SELECT TOP 10
    c.country,
    ROUND(SUM(v.totalamount),2) AS ingresos
FROM ventas v
JOIN clientes c
    ON v.customerid = c.customerid
GROUP BY c.country
ORDER BY ingresos DESC;

------------------------------------------------------------
-- Clientes con mayor frecuencia de compra
------------------------------------------------------------

SELECT TOP 10
    customerid,
    COUNT(invoiceno) AS frecuencia
FROM ventas
GROUP BY customerid
ORDER BY frecuencia DESC;


/* =========================================================
   12. CIERRE DEL PROYECTO SQL
========================================================= */

------------------------------------------------------------
-- Verificar estructura final del modelo relacional
------------------------------------------------------------

SELECT
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
ORDER BY TABLE_NAME;

------------------------------------------------------------
-- Visualizar relaciones (Foreign Keys)
------------------------------------------------------------

SELECT
    fk.name AS foreign_key,
    tp.name AS tabla_padre,
    tr.name AS tabla_referenciada
FROM sys.foreign_keys fk
INNER JOIN sys.tables tp
    ON fk.parent_object_id = tp.object_id
INNER JOIN sys.tables tr
    ON fk.referenced_object_id = tr.object_id;

------------------------------------------------------------
-- Fin del Proyecto
------------------------------------------------------------