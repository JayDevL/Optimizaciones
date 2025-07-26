--SEMANAL

CREATE OR ALTER PROCEDURE SP_RENDIMIENTO_CONSOLIDADO_SEMANAL
(
    @AGENCIA NVARCHAR(MAX),
    @TIPO_OPERACION NVARCHAR(MAX),
    @FECHA_INICIO_STRING VARCHAR(15),
    @FECHA_FIN_STRING VARCHAR(15)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FECHA_INICIO DATE = TRY_CONVERT(DATE, @FECHA_INICIO_STRING, 103);
    DECLARE @FECHA_FIN DATE = TRY_CONVERT(DATE, @FECHA_FIN_STRING, 103);

    IF (@TIPO_OPERACION = 'VACIO') SET @TIPO_OPERACION = NULL;

    DECLARE @semanaCols NVARCHAR(MAX) = '';
    DECLARE @sql NVARCHAR(MAX) = '';

    -- Detectar semanas únicas en el rango
    SELECT @semanaCols = COALESCE(@semanaCols + ', ', '') + QUOTENAME('SEMANA ' + CAST(DATEPART(WK, TRY_CONVERT(DATE, FECHA_INICIAL, 103)) AS VARCHAR))
    FROM (
        SELECT DISTINCT FECHA_INICIAL
        FROM TEL_MOTOR_TELEMETRIA
        WHERE TRY_CONVERT(DATE, FECHA_INICIAL, 103) BETWEEN @FECHA_INICIO AND @FECHA_FIN
    ) AS semanas;

    -- SQL dinámico completo
    SET @sql = '
SELECT 
    marca,
    agencia,
    tipo_operacion,
    año,
    economico,
    ruta,
    chofer,
    tipo_sensor,
    ' + @semanaCols + ',
    ROUND(SUM(kilometraje) / NULLIF(SUM(consumo_total), 0), 2) AS TOTAL
FROM (
    SELECT 
        Eco.marca,
        Eco.agencia,
        UPPER(LTRIM(RTRIM(Eco.tipo_operacion))) AS tipo_operacion,
        Eco.año,
        Eco.economico,
        Eco.ruta,
        Eco.chofer,
        Eco.tipo_sensor,
        ''SEMANA '' + CAST(DATEPART(WK, TRY_CONVERT(DATE, telm.FECHA_INICIAL, 103)) AS VARCHAR) AS SemanaX,
        SUM(TRY_CAST(telm.kilometraje AS DECIMAL(10,2))) AS kilometraje,
        SUM(TRY_CAST(telm.CONSUMO_TOTAL AS DECIMAL(10,2))) AS consumo_total
    FROM ECONOMICOS Eco
    INNER JOIN TEL_MOTOR_TELEMETRIA telm ON Eco.economico = telm.ECONOMICO
    WHERE 
        TRY_CONVERT(DATE, telm.FECHA_INICIAL, 103) BETWEEN ''' + @FECHA_INICIO_STRING + ''' AND ''' + @FECHA_FIN_STRING + '''
        AND Eco.economico != 1086
        AND '','' + REPLACE(UPPER(REPLACE(' + @AGENCIA + ', '' '', '''')), '','', '') + '' ''
    LIKE ''%'' + REPLACE(UPPER(Eco.agencia), '' '', '''') + ''%''
        AND (
            @TIPO_OPERACION IS NULL OR
            '','' + REPLACE(UPPER(REPLACE('+@TIPO_OPERACION+','''', ''))'',' ','', '') + ',' 
                LIKE ''%,'' + REPLACE(UPPER(REPLACE(LTRIM(RTRIM(Eco.tipo_operacion)), ' ', '')), ',', '') + '',%''
        )
    GROUP BY 
        Eco.marca, Eco.agencia, Eco.tipo_operacion, Eco.año, Eco.economico, Eco.ruta, Eco.chofer, Eco.tipo_sensor,
        DATEPART(WK, TRY_CONVERT(DATE, telm.FECHA_INICIAL, 103))
) AS datos
PIVOT (
    ROUND(SUM(kilometraje) / NULLIF(SUM(consumo_total), 0), 2)
    FOR SemanaX IN (' + @semanaCols + ')
) AS pvt
GROUP BY marca, agencia, tipo_operacion, año, economico, ruta, chofer, tipo_sensor
ORDER BY marca;
'
;

    EXEC sp_executesql @sql;
END;