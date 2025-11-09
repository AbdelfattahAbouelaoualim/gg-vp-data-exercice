{% macro text_similarity(str1, str2) %}
    {#
        Calcule la similarité entre deux chaînes de caractères.
        Utilise EDITDISTANCE (Levenshtein) et normalise le score.

        Formule:
        similarity = 1 - (edit_distance / max_length)

        Args:
            str1, str2: Chaînes à comparer

        Returns:
            Score de similarité entre 0 et 1 (FLOAT)
            - 1.0 = chaînes identiques
            - 0.0 = chaînes totalement différentes
    #}
    (
        1.0 - (
            EDITDISTANCE(
                UPPER({{ str1 }}),
                UPPER({{ str2 }})
            ) / GREATEST(
                LENGTH({{ str1 }}),
                LENGTH({{ str2 }}),
                1
            )
        )
    )
{% endmacro %}
