package com.example.bookmanagement.dto;

public record BookDto(
                Long id,
                String title,
                Long authorId,
                String authorName,
                Long publisherId,
                String publisherName) {
}