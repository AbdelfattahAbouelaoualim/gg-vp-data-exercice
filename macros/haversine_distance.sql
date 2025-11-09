{% macro haversine_distance(lat1, lon1, lat2, lon2) %}
    {#
        Calcule la distance Haversine en kilomètres entre deux points GPS.

        Formule Haversine:
        a = sin²(lat/2) + cos(lat1) * cos(lat2) * sin²(lon/2)
        c = 2 * atan2(a, (1a))
        distance = R * c (R = 6371 km)

        Args:
            lat1, lon1: Coordonnées du point 1 (en degrés)
            lat2, lon2: Coordonnées du point 2 (en degrés)

        Returns:
            Distance en kilomètres (FLOAT)
    #}
    (
        6371 * 2 * ASIN(
            SQRT(
                POWER(SIN(RADIANS(({{ lat2 }} - {{ lat1 }})) / 2), 2) +
                COS(RADIANS({{ lat1 }})) *
                COS(RADIANS({{ lat2 }})) *
                POWER(SIN(RADIANS(({{ lon2 }} - {{ lon1 }})) / 2), 2)
            )
        )
    )
{% endmacro %}
