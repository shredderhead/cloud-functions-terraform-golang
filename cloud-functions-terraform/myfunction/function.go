package myfunction

import (
	"fmt"
	"net/http"
)

func RunFunction() {
	fmt.Println("Hello, GCP CLOUD FUNCTION...")
}

func Handler(w http.ResponseWriter, r *http.Request) {
	RunFunction()
}
