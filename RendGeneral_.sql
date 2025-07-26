USE [BICYR_TEL]
GO
/****** Object:  StoredProcedure [dbo].[ReporteGeneralTelemetria_Dev]    Script Date: 25/07/2025 22:35:16 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[ReporteGeneralTelemetria_Dev]
(   
    @FI VARCHAR(15),
    @FF VARCHAR(15),
    @AGENCIA VARCHAR(50),
    @TIPO_OPERACION VARCHAR(1000) = 'VACIO'
)  
AS  
BEGIN
    
    DECLARE @FECHA_INICIO DATE = TRY_CONVERT(DATE,@FI,103)

     DECLARE @FECHA_FIN DATE = TRY_CONVERT(DATE,@FF,103)

    IF (@TIPO_OPERACION = 'VACIO')
    BEGIN
        SET @TIPO_OPERACION = NULL;
    END;

    SELECT 
        Eco.marca,
        Eco.agencia,
        LTRIM(RTRIM(Eco.tipo_operacion)) AS tipo_operacion,
        Eco.año,
        Eco.economico,
        Eco.ruta,
        Eco.chofer,
		Eco.tipo,
        Eco.tipo_sensor,

        -- Rendimiento
        CASE 
            WHEN SUM(TRY_CAST(telm.CONSUMO_TOTAL AS DECIMAL(10,2))) = 0 THEN 
                CASE
                    WHEN ISNULL((
                        SELECT SUM(TRY_CAST(le.CANTIDAD AS DECIMAL(10,2)))
                        FROM TEL_COMBUSTIBLE le
                        WHERE le.ECONOMICO = Eco.economico 
                              AND TRY_CONVERT(DATE, le.FECHA, 103) BETWEEN @FECHA_INICIO AND @FECHA_FIN
                    ), 0) = 0 THEN 0
                    ELSE 
                        SUM(TRY_CAST(telm.kilometraje AS DECIMAL(10,2))) /
                        ISNULL((
                            SELECT SUM(TRY_CAST(le.CANTIDAD AS DECIMAL(10,2)))
                            FROM TEL_COMBUSTIBLE le
                            WHERE le.ECONOMICO = Eco.economico 
                                  AND TRY_CONVERT(DATE, le.FECHA, 103) BETWEEN @FECHA_INICIO AND @FECHA_FIN
                        ), 0)
                END
            ELSE 
                SUM(TRY_CAST(telm.kilometraje AS DECIMAL(10,2))) / 
                SUM(TRY_CAST(telm.CONSUMO_TOTAL AS DECIMAL(10,2)))
        END AS rendimiento,

        SUM(TRY_CAST(telm.CONSUMO_RALENTI AS DECIMAL(10,2))) AS ralenti,
        ISNULL(tvt.rpm_max, 0) AS rpm_max,
        ISNULL(tvt.max_vel, 0) AS max_vel,
        SUM(TRY_CAST(telm.kilometraje AS DECIMAL(10,2))) AS km_total,

        CASE 
            WHEN SUM(TRY_CAST(telm.CONSUMO_TOTAL AS DECIMAL(10,2))) = 0 THEN 
                ISNULL((
                    SELECT SUM(TRY_CAST(le.CANTIDAD AS DECIMAL(10,2)))
                    FROM TEL_COMBUSTIBLE le
                    WHERE le.ECONOMICO = Eco.economico 
                          AND TRY_CONVERT(DATE, le.FECHA, 103) BETWEEN @FECHA_INICIO AND @FECHA_FIN
                ), 0)
            ELSE 
                SUM(TRY_CAST(telm.CONSUMO_TOTAL AS DECIMAL(10,2)))
        END AS consumo_total,

        ISNULL((
            SELECT SUM(TRY_CAST(le.CANTIDAD AS DECIMAL(10,2)))
            FROM TEL_COMBUSTIBLE le
            WHERE le.ECONOMICO = Eco.economico 
                  AND TRY_CONVERT(DATE, le.FECHA, 103) BETWEEN @FECHA_INICIO AND @FECHA_FIN
        ), 0) AS gasolina_lts

    FROM ECONOMICOS AS Eco

    INNER JOIN TEL_MOTOR_TELEMETRIA AS telm
        ON Eco.economico = telm.ECONOMICO

    LEFT JOIN (
        SELECT
            ECONOMICO,
            MAX(TRY_CAST(REVO_MAX_MOTOR AS DECIMAL(10,2))) AS rpm_max,
            MAX(TRY_CAST(VELOCIDAD_MAX AS DECIMAL(10,2))) AS max_vel
        FROM TEL_VIAJES_TELEMETRIA
        WHERE TRY_CONVERT(DATE, FECHA_INICIAL, 103) BETWEEN @FECHA_INICIO AND @FECHA_FIN
        GROUP BY ECONOMICO
    ) AS tvt ON Eco.economico = tvt.ECONOMICO

    WHERE 
    TRY_CONVERT(DATE, telm.FECHA_INICIAL, 103) 
        BETWEEN @FECHA_INICIO AND @FECHA_FIN
    AND ',' + REPLACE(UPPER(REPLACE(@AGENCIA, ', ', ',')), ' ', '') + ',' 
        LIKE '%,' + REPLACE(UPPER(REPLACE(LTRIM(RTRIM(Eco.agencia)), ' ', '')), ' ', '') + ',%'
    AND (
        @TIPO_OPERACION IS NULL OR 
        ',' + REPLACE(UPPER(REPLACE(@TIPO_OPERACION, ', ', ',')), ' ', '') + ',' 
            LIKE '%,' + REPLACE(UPPER(REPLACE(LTRIM(RTRIM(Eco.tipo_operacion)), ' ', '')), ' ', '') + ',%'
    )

	and Eco.economico != 1086

    GROUP BY 
        Eco.economico, Eco.agencia, Eco.tipo_operacion, Eco.marca, Eco.año, Eco.ruta, Eco.chofer, Eco.tipo_sensor, Eco.tipo, tvt.rpm_max, tvt.max_vel

    ORDER BY Eco.marca ASC;
END;