package com.example.bookmanagement.controller;

import com.example.bookmanagement.dto.BookDto;
import com.example.bookmanagement.dto.BookImportResponse;
import com.example.bookmanagement.service.BookService;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.sql.SQLException;
import java.util.List;

@RestController
@RequestMapping("/api/books")
public class BookController {

    private final BookService bookService;

    public BookController(BookService bookService) {
        this.bookService = bookService;
    }

    @PostMapping(
            value = "/import",
            consumes = MediaType.TEXT_PLAIN_VALUE,
            produces = MediaType.APPLICATION_JSON_VALUE
    )
    public ResponseEntity<BookImportResponse> importBooks(
            @RequestBody String rawData
    ) throws SQLException {

        BookImportResponse response = bookService.importBooks(rawData);

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(response);
    }

    @GetMapping(produces = MediaType.APPLICATION_JSON_VALUE)
    public List<BookDto> getAllBooks() throws SQLException {
        return bookService.getAllBooks();
    }
}