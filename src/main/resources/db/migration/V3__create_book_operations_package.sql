CREATE OR REPLACE PACKAGE BOOK_OPERATIONS AS

    FUNCTION RAW_TO_XML(
        p_raw IN VARCHAR2
    ) RETURN CLOB;

    FUNCTION RAW_TO_JSON(
        p_raw IN VARCHAR2
    ) RETURN CLOB;

    PROCEDURE IMPORT_BOOKS(
        p_xml  IN CLOB,
        p_json IN CLOB
    );

    PROCEDURE GET_ALL_BOOKS(
        p_result OUT SYS_REFCURSOR
    );

END BOOK_OPERATIONS;
/

CREATE OR REPLACE PACKAGE BODY BOOK_OPERATIONS AS

    ------------------------------------------------------------------
    -- Bir kaydı title|author|publisher biçiminde parçalar.
    ------------------------------------------------------------------
    PROCEDURE SPLIT_RECORD(
        p_record        IN VARCHAR2,
        p_title         OUT VARCHAR2,
        p_author_name   OUT VARCHAR2,
        p_publisher_name OUT VARCHAR2
    ) IS
        v_pipe_count NUMBER;
    BEGIN
        v_pipe_count :=
            LENGTH(p_record) - LENGTH(REPLACE(p_record, '|', ''));

        IF v_pipe_count <> 2 THEN
            RAISE_APPLICATION_ERROR(
                -20001,
                'Her kitap kaydi title|author|publisher formatinda olmalidir.'
            );
        END IF;

        p_title :=
            TRIM(REGEXP_SUBSTR(p_record, '[^|]+', 1, 1));

        p_author_name :=
            TRIM(REGEXP_SUBSTR(p_record, '[^|]+', 1, 2));

        p_publisher_name :=
            TRIM(REGEXP_SUBSTR(p_record, '[^|]+', 1, 3));

        IF p_title IS NULL
           OR p_author_name IS NULL
           OR p_publisher_name IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20001,
                'Kitap basligi, yazar ve yayinevi bos olamaz.'
            );
        END IF;

        IF LENGTH(p_title) > 300 THEN
            RAISE_APPLICATION_ERROR(
                -20001,
                'Kitap basligi 300 karakterden uzun olamaz.'
            );
        END IF;

        IF LENGTH(p_author_name) > 200
           OR LENGTH(p_publisher_name) > 200 THEN
            RAISE_APPLICATION_ERROR(
                -20001,
                'Yazar veya yayinevi adi 200 karakterden uzun olamaz.'
            );
        END IF;
    END SPLIT_RECORD;


    ------------------------------------------------------------------
    -- Ham veriyi XML biçimine dönüştürür.
    ------------------------------------------------------------------
    FUNCTION RAW_TO_XML(
        p_raw IN VARCHAR2
    ) RETURN CLOB IS
        v_xml            CLOB := '<books>';
        v_fragment       CLOB;
        v_record         VARCHAR2(4000);
        v_title          VARCHAR2(300);
        v_author_name    VARCHAR2(200);
        v_publisher_name VARCHAR2(200);
        v_index          PLS_INTEGER := 1;
    BEGIN
        IF p_raw IS NULL OR TRIM(p_raw) IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20001,
                'Ham kitap verisi bos olamaz.'
            );
        END IF;

        IF p_raw LIKE ';%'
           OR p_raw LIKE '%;'
           OR INSTR(p_raw, ';;') > 0 THEN
            RAISE_APPLICATION_ERROR(
                -20001,
                'Bos kitap kaydi veya gecersiz noktalı virgul kullanimi.'
            );
        END IF;

        LOOP
            v_record :=
                REGEXP_SUBSTR(p_raw, '[^;]+', 1, v_index);

            EXIT WHEN v_record IS NULL;

            SPLIT_RECORD(
                p_record         => v_record,
                p_title          => v_title,
                p_author_name    => v_author_name,
                p_publisher_name => v_publisher_name
            );

            SELECT XMLSERIALIZE(
                       CONTENT XMLELEMENT(
                           "book",
                           XMLELEMENT("title", v_title),
                           XMLELEMENT("author", v_author_name),
                           XMLELEMENT("publisher", v_publisher_name)
                       )
                       AS CLOB
                   )
              INTO v_fragment
              FROM DUAL;

            v_xml := v_xml || v_fragment;
            v_index := v_index + 1;
        END LOOP;

        v_xml := v_xml || '</books>';

        RETURN v_xml;

    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE BETWEEN -20999 AND -20000 THEN
                RAISE;
            END IF;

            RAISE_APPLICATION_ERROR(
                -20001,
                'XML olusturulamadi: ' || SUBSTR(SQLERRM, 1, 1000)
            );
    END RAW_TO_XML;


    ------------------------------------------------------------------
    -- Ham veriyi JSON biçimine dönüştürür.
    ------------------------------------------------------------------
    FUNCTION RAW_TO_JSON(
        p_raw IN VARCHAR2
    ) RETURN CLOB IS
        v_json           CLOB := '[';
        v_fragment       CLOB;
        v_record         VARCHAR2(4000);
        v_title          VARCHAR2(300);
        v_author_name    VARCHAR2(200);
        v_publisher_name VARCHAR2(200);
        v_index          PLS_INTEGER := 1;
        v_first_record   BOOLEAN := TRUE;
    BEGIN
        IF p_raw IS NULL OR TRIM(p_raw) IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20001,
                'Ham kitap verisi bos olamaz.'
            );
        END IF;

        IF p_raw LIKE ';%'
           OR p_raw LIKE '%;'
           OR INSTR(p_raw, ';;') > 0 THEN
            RAISE_APPLICATION_ERROR(
                -20001,
                'Bos kitap kaydi veya gecersiz noktalı virgul kullanimi.'
            );
        END IF;

        LOOP
            v_record :=
                REGEXP_SUBSTR(p_raw, '[^;]+', 1, v_index);

            EXIT WHEN v_record IS NULL;

            SPLIT_RECORD(
                p_record         => v_record,
                p_title          => v_title,
                p_author_name    => v_author_name,
                p_publisher_name => v_publisher_name
            );

            SELECT JSON_OBJECT(
                       'title' VALUE v_title,
                       'author' VALUE v_author_name,
                       'publisher' VALUE v_publisher_name
                       RETURNING CLOB
                   )
              INTO v_fragment
              FROM DUAL;

            IF NOT v_first_record THEN
                v_json := v_json || ',';
            END IF;

            v_json := v_json || v_fragment;
            v_first_record := FALSE;
            v_index := v_index + 1;
        END LOOP;

        v_json := v_json || ']';

        RETURN v_json;

    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE BETWEEN -20999 AND -20000 THEN
                RAISE;
            END IF;

            RAISE_APPLICATION_ERROR(
                -20001,
                'JSON olusturulamadi: ' || SUBSTR(SQLERRM, 1, 1000)
            );
    END RAW_TO_JSON;


    ------------------------------------------------------------------
    -- XMLTABLE ve JSON_TABLE kullanarak verileri tablolara ekler.
    ------------------------------------------------------------------
    PROCEDURE IMPORT_BOOKS(
        p_xml  IN CLOB,
        p_json IN CLOB
    ) IS
        v_xml_document XMLTYPE;
        v_json_valid   NUMBER;
        v_xml_count    NUMBER;
        v_json_count   NUMBER;
        v_author_id    AUTHORS.ID%TYPE;
        v_publisher_id PUBLISHERS.ID%TYPE;
        v_record_count NUMBER := 0;
    BEGIN
        IF p_xml IS NULL OR p_json IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20002,
                'XML ve JSON girdileri bos olamaz.'
            );
        END IF;

        BEGIN
            v_xml_document := XMLTYPE(p_xml);
        EXCEPTION
            WHEN OTHERS THEN
                RAISE_APPLICATION_ERROR(
                    -20002,
                    'Gecersiz XML verisi.'
                );
        END;

        SELECT CASE
                   WHEN p_json IS JSON THEN 1
                   ELSE 0
               END
          INTO v_json_valid
          FROM DUAL;

        IF v_json_valid = 0 THEN
            RAISE_APPLICATION_ERROR(
                -20002,
                'Gecersiz JSON verisi.'
            );
        END IF;

        SELECT COUNT(*)
          INTO v_xml_count
          FROM XMLTABLE(
                   '/books/book'
                   PASSING v_xml_document
                   COLUMNS
                       title          VARCHAR2(300) PATH 'title',
                       author_name    VARCHAR2(200) PATH 'author',
                       publisher_name VARCHAR2(200) PATH 'publisher'
               );

        SELECT COUNT(*)
          INTO v_json_count
          FROM JSON_TABLE(
                   p_json,
                   '$[*]'
                   COLUMNS
                       title          VARCHAR2(300) PATH '$.title',
                       author_name    VARCHAR2(200) PATH '$.author',
                       publisher_name VARCHAR2(200) PATH '$.publisher'
               );

        IF v_xml_count = 0 OR v_json_count = 0 THEN
            RAISE_APPLICATION_ERROR(
                -20003,
                'XML veya JSON icinde kitap kaydi bulunamadi.'
            );
        END IF;

        IF v_xml_count <> v_json_count THEN
            RAISE_APPLICATION_ERROR(
                -20003,
                'XML ve JSON kitap sayilari birbiriyle uyusmuyor.'
            );
        END IF;

        FOR r_book IN (
            SELECT title,
                   author_name,
                   publisher_name
              FROM (
                    SELECT xt.title,
                           xt.author_name,
                           xt.publisher_name
                      FROM XMLTABLE(
                               '/books/book'
                               PASSING v_xml_document
                               COLUMNS
                                   title VARCHAR2(300)
                                       PATH 'title',
                                   author_name VARCHAR2(200)
                                       PATH 'author',
                                   publisher_name VARCHAR2(200)
                                       PATH 'publisher'
                           ) xt

                    UNION

                    SELECT jt.title,
                           jt.author_name,
                           jt.publisher_name
                      FROM JSON_TABLE(
                               p_json,
                               '$[*]'
                               COLUMNS
                                   title VARCHAR2(300)
                                       PATH '$.title',
                                   author_name VARCHAR2(200)
                                       PATH '$.author',
                                   publisher_name VARCHAR2(200)
                                       PATH '$.publisher'
                           ) jt
                   )
        ) LOOP
            IF TRIM(r_book.title) IS NULL
               OR TRIM(r_book.author_name) IS NULL
               OR TRIM(r_book.publisher_name) IS NULL THEN
                RAISE_APPLICATION_ERROR(
                    -20003,
                    'Kitap, yazar veya yayinevi bilgisi bos olamaz.'
                );
            END IF;

            v_record_count := v_record_count + 1;

            MERGE INTO AUTHORS a
            USING (
                SELECT TRIM(r_book.author_name) AS name
                  FROM DUAL
            ) source_author
            ON (
                a.NAME = source_author.NAME
            )
            WHEN NOT MATCHED THEN
                INSERT (NAME)
                VALUES (source_author.NAME);

            SELECT ID
              INTO v_author_id
              FROM AUTHORS
             WHERE NAME = TRIM(r_book.author_name);

            MERGE INTO PUBLISHERS p
            USING (
                SELECT TRIM(r_book.publisher_name) AS name
                  FROM DUAL
            ) source_publisher
            ON (
                p.NAME = source_publisher.NAME
            )
            WHEN NOT MATCHED THEN
                INSERT (NAME)
                VALUES (source_publisher.NAME);

            SELECT ID
              INTO v_publisher_id
              FROM PUBLISHERS
             WHERE NAME = TRIM(r_book.publisher_name);

            INSERT INTO BOOKS (
                TITLE,
                AUTHOR_ID,
                PUBLISHER_ID
            )
            SELECT TRIM(r_book.title),
                   v_author_id,
                   v_publisher_id
              FROM DUAL
             WHERE NOT EXISTS (
                       SELECT 1
                         FROM BOOKS b
                        WHERE b.TITLE = TRIM(r_book.title)
                          AND b.AUTHOR_ID = v_author_id
                          AND b.PUBLISHER_ID = v_publisher_id
                   );
        END LOOP;

        IF v_record_count = 0 THEN
            RAISE_APPLICATION_ERROR(
                -20003,
                'Islenecek kitap kaydi bulunamadi.'
            );
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;

            IF SQLCODE BETWEEN -20999 AND -20000 THEN
                RAISE;
            END IF;

            RAISE_APPLICATION_ERROR(
                -20004,
                'Kitap aktarimi basarisiz: '
                || SUBSTR(SQLERRM, 1, 1000)
            );
    END IMPORT_BOOKS;


    ------------------------------------------------------------------
    -- Java tarafına tüm kitapları SYS_REFCURSOR olarak döndürür.
    ------------------------------------------------------------------
    PROCEDURE GET_ALL_BOOKS(
        p_result OUT SYS_REFCURSOR
    ) IS
    BEGIN
        OPEN p_result FOR
            SELECT b.ID,
                   b.TITLE,
                   a.ID AS AUTHOR_ID,
                   a.NAME AS AUTHOR_NAME,
                   p.ID AS PUBLISHER_ID,
                   p.NAME AS PUBLISHER_NAME
              FROM BOOKS b
              JOIN AUTHORS a
                ON a.ID = b.AUTHOR_ID
              JOIN PUBLISHERS p
                ON p.ID = b.PUBLISHER_ID
             ORDER BY b.ID;
    END GET_ALL_BOOKS;

END BOOK_OPERATIONS;
/