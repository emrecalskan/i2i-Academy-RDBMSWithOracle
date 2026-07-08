package com.example.bookmanagement.service;

import com.example.bookmanagement.dto.BookDto;
import com.example.bookmanagement.dto.BookImportResponse;
import org.springframework.stereotype.Service;

import javax.sql.DataSource;
import java.io.StringReader;
import java.sql.CallableStatement;
import java.sql.Clob;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.util.ArrayList;
import java.util.List;

@Service
public class BookService {

    private static final String RAW_TO_XML_CALL = "{? = call BOOK_OPERATIONS.RAW_TO_XML(?)}";

    private static final String RAW_TO_JSON_CALL = "{? = call BOOK_OPERATIONS.RAW_TO_JSON(?)}";

    private static final String IMPORT_BOOKS_CALL = "{call BOOK_OPERATIONS.IMPORT_BOOKS(?, ?)}";

    private static final String GET_ALL_BOOKS_CALL = "{call BOOK_OPERATIONS.GET_ALL_BOOKS(?)}";

    private final DataSource dataSource;

    public BookService(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    /**
     * Ham metni PL/SQL fonksiyonlarıyla XML ve JSON'a dönüştürür,
     * ardından IMPORT_BOOKS prosedürüne gönderir.
     */
    public BookImportResponse importBooks(String rawData) throws SQLException {
        if (rawData == null || rawData.isBlank()) {
            throw new IllegalArgumentException(
                    "İçe aktarılacak kitap verisi boş olamaz.");
        }

        try (Connection connection = dataSource.getConnection()) {
            boolean originalAutoCommit = connection.getAutoCommit();
            connection.setAutoCommit(false);

            try {
                String xml = callClobFunction(
                        connection,
                        RAW_TO_XML_CALL,
                        rawData);

                String json = callClobFunction(
                        connection,
                        RAW_TO_JSON_CALL,
                        rawData);

                callImportProcedure(connection, xml, json);

                connection.commit();

                return new BookImportResponse(
                        "Kitaplar başarıyla içe aktarıldı.",
                        xml,
                        json);
            } catch (SQLException exception) {
                rollback(connection, exception);
                throw exception;
            } finally {
                connection.setAutoCommit(originalAutoCommit);
            }
        }
    }

    /**
     * PL/SQL paketindeki CLOB döndüren bir fonksiyonu çağırır.
     */
    private String callClobFunction(
            Connection connection,
            String callSql,
            String rawData) throws SQLException {

        try (CallableStatement statement = connection.prepareCall(callSql)) {

            statement.registerOutParameter(1, Types.CLOB);
            statement.setString(2, rawData);
            statement.execute();

            Clob resultClob = statement.getClob(1);

            if (resultClob == null) {
                throw new SQLException(
                        "PL/SQL fonksiyonu boş sonuç döndürdü.");
            }

            try {
                long length = resultClob.length();

                if (length > Integer.MAX_VALUE) {
                    throw new SQLException(
                            "PL/SQL fonksiyonunun sonucu işlenemeyecek kadar büyük.");
                }

                return resultClob.getSubString(1, (int) length);
            } finally {
                resultClob.free();
            }
        }
    }

    /**
     * XML ve JSON verilerini PL/SQL IMPORT_BOOKS prosedürüne gönderir.
     */
    private void callImportProcedure(
            Connection connection,
            String xml,
            String json) throws SQLException {

        try (CallableStatement statement = connection.prepareCall(IMPORT_BOOKS_CALL)) {

            statement.setClob(1, new StringReader(xml));
            statement.setClob(2, new StringReader(json));
            statement.execute();
        }
    }

    /**
     * PL/SQL SYS_REFCURSOR çıktısını Java DTO listesine dönüştürür.
     */
    public List<BookDto> getAllBooks() throws SQLException {
        List<BookDto> books = new ArrayList<>();

        try (Connection connection = dataSource.getConnection();
                CallableStatement statement = connection.prepareCall(GET_ALL_BOOKS_CALL)) {

            statement.registerOutParameter(1, Types.REF_CURSOR);
            statement.execute();

            try (ResultSet resultSet = (ResultSet) statement.getObject(1)) {

                while (resultSet.next()) {
                    BookDto book = new BookDto(
                            resultSet.getLong("ID"),
                            resultSet.getString("TITLE"),
                            resultSet.getLong("AUTHOR_ID"),
                            resultSet.getString("AUTHOR_NAME"),
                            resultSet.getLong("PUBLISHER_ID"),
                            resultSet.getString("PUBLISHER_NAME"));

                    books.add(book);
                }
            }
        }

        return books;
    }

    /**
     * Asıl SQL hatasını koruyarak transaction'ı geri alır.
     */
    private void rollback(
            Connection connection,
            SQLException originalException) {
        try {
            connection.rollback();
        } catch (SQLException rollbackException) {
            originalException.addSuppressed(rollbackException);
        }
    }
}