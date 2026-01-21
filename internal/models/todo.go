package models

type Todo struct {
	ID        int    `json:"id" db:"id"`
	Title     string `json:"title" db:"title"`
	Completed bool   `json:"completed" db:"completed"`
	CreatedAt string `json:"created_at" db:"created_at"`
	UpdatedAt string `json:"updated_at" db:"updated_at"`
}
