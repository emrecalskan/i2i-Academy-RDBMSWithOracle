package com.example.bookmanagement.dto;

public record BookImportResponse(
        String message,
        String xml,
        String json) {
}