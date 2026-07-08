package com.example.bookmanagement.exception;

import com.example.bookmanagement.dto.ApiErrorResponse;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.sql.SQLException;
import java.time.LocalDateTime;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<ApiErrorResponse> handleIllegalArgumentException(
            IllegalArgumentException exception
    ) {
        return createResponse(
                HttpStatus.BAD_REQUEST,
                exception.getMessage()
        );
    }

    @ExceptionHandler(SQLException.class)
    public ResponseEntity<ApiErrorResponse> handleSQLException(
            SQLException exception
    ) {
        int oracleErrorCode = Math.abs(exception.getErrorCode());

        boolean customBusinessError =
                oracleErrorCode >= 20000
                        && oracleErrorCode <= 20999;

        HttpStatus status = customBusinessError
                ? HttpStatus.BAD_REQUEST
                : HttpStatus.INTERNAL_SERVER_ERROR;

        String message = exception.getMessage();

        if (message == null || message.isBlank()) {
            message = customBusinessError
                    ? "Geçersiz kitap verisi."
                    : "Veritabanı işlemi sırasında bir hata oluştu.";
        }

        return createResponse(status, message);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiErrorResponse> handleUnexpectedException(
            Exception exception
    ) {
        return createResponse(
                HttpStatus.INTERNAL_SERVER_ERROR,
                "Beklenmeyen bir sunucu hatası oluştu."
        );
    }

    private ResponseEntity<ApiErrorResponse> createResponse(
            HttpStatus status,
            String message
    ) {
        ApiErrorResponse response = new ApiErrorResponse(
                status.value(),
                status.getReasonPhrase(),
                message,
                LocalDateTime.now()
        );

        return ResponseEntity
                .status(status)
                .body(response);
    }
}