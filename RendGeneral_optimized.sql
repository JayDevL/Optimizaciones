
--OPTIMIZADO 25-07-2025

USE [BICYR_TEL]
GO
/****** Object:  StoredProcedure [dbo].[SP_RENDIMIENTO_CONSOLIDADO]    Script Date: 25/07/2025 22:23:32 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[SP_RENDIMIENTO_CONSOLIDADO]
    @AGENCIA NVARCHAR(MAX),
    @TIPO_OPERACION NVARCHAR(MAX),
    @FECHA_INICIO DATE,
    @FECHA_FIN DATE
AS
BEGIN
    -- 🧱 Paso 1: Normalización de parámetros
    IF (@TIPO_OPERACION = 'VACIO')
    BEGIN
        SET @TIPO_OPERACION = NULL;
    END;

    -- 🧩 Paso 2: Definición de CTEs
    WITH AgenciasFiltradas AS (
        SELECT TRIM(UPPER(value)) AS Agencia
        FROM STRING_SPLIT(@AGENCIA, ',')
    ),
    OperacionesFiltradas AS (
        SELECT TRIM(UPPER(value)) AS TipoOperacion
        FROM STRING_SPLIT(@TIPO_OPERACION, ',')
    ),
    TelemetriaFiltrada AS (
        SELECT *
        FROM TEL_MOTOR_TELEMETRIA
        WHERE TRY_CONVERT(DATE,FECHA_INICIAL,103) BETWEEN @FECHA_INICIO AND @FECHA_FIN
    ),
    MaximosTelemetria AS (
        SELECT
            ECONOMICO,
            MAX(TRY_CAST(REVO_MAX_MOTOR AS DECIMAL(10,2))) AS rpm_max,
            MAX(TRY_CAST(VELOCIDAD_MAX AS DECIMAL(10,2))) AS max_vel
        FROM TEL_VIAJES_TELEMETRIA
        WHERE TRY_CONVERT(DATE,FECHA_INICIAL,103) BETWEEN @FECHA_INICIO AND @FECHA_FIN
        GROUP BY ECONOMICO
    ),
    GasolinaPorEconomico AS (
        SELECT
            ECONOMICO,
            SUM(TRY_CAST(CANTIDAD AS DECIMAL(10,2))) AS gasolina_lts
        FROM TEL_COMBUSTIBLE
        WHERE TRY_CONVERT(DATE,FECHA,103) BETWEEN @FECHA_INICIO AND @FECHA_FIN
        GROUP BY ECONOMICO
    )

    -- 📦 Paso 3: Consulta final
    SELECT
        Eco.marca,
        Eco.agencia,
        TRIM(Eco.tipo_operacion) AS tipo_operacion,
        Eco.año,
        Eco.economico,
        Eco.ruta,
        Eco.chofer,
        Eco.tipo,
        Eco.tipo_sensor,

        -- Rendimiento calculado
        CASE
            WHEN SUM(TRY_CAST(telm.CONSUMO_TOTAL AS DECIMAL(10,2))) = 0 THEN
                CASE
                    WHEN ISNULL(Comb.gasolina_lts, 0) = 0 THEN 0
                    ELSE SUM(TRY_CAST(telm.kilometraje AS DECIMAL(10,2))) / ISNULL(Comb.gasolina_lts, 1)
                END
            ELSE
                SUM(TRY_CAST(telm.kilometraje AS DECIMAL(10,2))) / SUM(TRY_CAST(telm.CONSUMO_TOTAL AS DECIMAL(10,2)))
        END AS rendimiento,

        SUM(TRY_CAST(telm.CONSUMO_RALENTI AS DECIMAL(10,2))) AS ralenti,
        ISNULL(tvt.rpm_max, 0) AS rpm_max,
        ISNULL(tvt.max_vel, 0) AS max_vel,
        SUM(TRY_CAST(telm.kilometraje AS DECIMAL(10,2))) AS km_total,

        -- Consumo total con fallback
        CASE
            WHEN SUM(TRY_CAST(telm.CONSUMO_TOTAL AS DECIMAL(10,2))) = 0 THEN ISNULL(Comb.gasolina_lts, 0)
            ELSE SUM(TRY_CAST(telm.CONSUMO_TOTAL AS DECIMAL(10,2)))
        END AS consumo_total,

        ISNULL(Comb.gasolina_lts, 0) AS gasolina_lts

    FROM ECONOMICOS AS Eco
    INNER JOIN TelemetriaFiltrada AS telm ON Eco.economico = telm.ECONOMICO
    LEFT JOIN MaximosTelemetria AS tvt ON Eco.economico = tvt.ECONOMICO
    LEFT JOIN GasolinaPorEconomico AS Comb ON Eco.economico = Comb.ECONOMICO

    WHERE
        EXISTS (
            SELECT 1 FROM AgenciasFiltradas AS a
            WHERE a.Agencia = TRIM(UPPER(Eco.agencia))
        )
        AND (
            @TIPO_OPERACION IS NULL OR EXISTS (
                SELECT 1 FROM OperacionesFiltradas AS t
                WHERE t.TipoOperacion = TRIM(UPPER(Eco.tipo_operacion))
            )
        )
        AND Eco.economico != 1086

    GROUP BY 
        Eco.economico, Eco.agencia, Eco.tipo_operacion, Eco.marca, Eco.año, Eco.ruta, Eco.chofer, Eco.tipo_sensor, Eco.tipo,
        tvt.rpm_max, tvt.max_vel, Comb.gasolina_lts

    ORDER BY Eco.marca ASC;
END;