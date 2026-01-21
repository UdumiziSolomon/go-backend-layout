package repository

import (
	"context"
	"log"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/solonode/go-learn/internal/models"
)

func CreateTodoRepository(pool *pgxpool.Pool, title string, completed bool) (*models.Todo, error) {
	var ctx context.Context
	var cancel context.CancelFunc

	ctx, cancel = context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var query string = `
		INSERT INTO todos (title, completed)
		VALUES ($1, $2)
		RETURNING id, title, completed, created_at, updated_at
	`

	var todo models.Todo
	err := pool.QueryRow(ctx, query, title, completed).Scan(&todo.ID, &todo.Title, &todo.Completed, &todo.CreatedAt, &todo.UpdatedAt)

	if err != nil {
		log.Printf("Unable to create todo: %v", err)
		return nil, err
	}

	return &todo, nil
}

func GetAllTodosRepository(pool *pgxpool.Pool) ([]models.Todo, error) {
	var ctx context.Context
	var cancel context.CancelFunc

	ctx, cancel = context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var query string = `
		SELECT id, title, completed, created_at, updated_at
		FROM todos
		ORDER BY created_at DESC
	`

	rows, err := pool.Query(ctx, query)

	if err != nil {
		log.Printf("Unable to get todos: %v", err)
		return nil, err
	}

	defer rows.Close()

	var todos []models.Todo = []models.Todo{}

	for rows.Next() {
		var todo models.Todo
		err := rows.Scan(&todo.ID, &todo.Title, &todo.Completed, &todo.CreatedAt, &todo.UpdatedAt)

		if err != nil {
			log.Printf("Unable to scan todo: %v", err)
			return nil, err
		}

		todos = append(todos, todo)
	}

	return todos, nil
}

func GetTodoByIdRepository(pool *pgxpool.Pool, id int) (*models.Todo, error) {
	var ctx context.Context
	var cancel context.CancelFunc

	ctx, cancel = context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var query string = `
		SELECT id, title, completed, created_at, updated_at
		FROM todos
		WHERE id = $1
	`

	var todo models.Todo
	err := pool.QueryRow(ctx, query, id).Scan(&todo.ID, &todo.Title, &todo.Completed, &todo.CreatedAt, &todo.UpdatedAt)

	if err != nil {
		log.Printf("Unable to get todo: %v", err)
		return nil, err
	}

	return &todo, nil
}
