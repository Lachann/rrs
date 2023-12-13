package server

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/gorilla/mux"
)

func Start(host, rickroll string, previews []string) error {
	router := mux.NewRouter()

	router.HandleFunc("/r/{bust}/{url:.*}", func(w http.ResponseWriter, r *http.Request) {
		params := mux.Vars(r)
		bust := params["bust"]
		url := params["url"]

		if !strings.HasPrefix(url, "http") {
			url = "https://" + url
		}

		useragent := r.Header.Get("User-Agent")
		origin := r.RemoteAddr

		shouldFake := false
		for _, p := range previews {
			if strings.Contains(useragent, p) {
				shouldFake = true
				break
			}
		}

		if shouldFake {
			fmt.Printf("%s: request %s from %s by %s, showing %s\n", time.Now().Round(0), bust, origin, useragent, url)
			http.Redirect(w, r, url, http.StatusFound)
		} else {
			fmt.Printf("%s: request %s from %s by %s, showing %s\n", time.Now().Round(0), bust, origin, useragent, "rickroll")
			http.Redirect(w, r, rickroll, http.StatusFound)
		}
	})

	fmt.Printf("Starting server on %s\n", host)
	if err := http.ListenAndServe(host, router); err != nil {
		fmt.Printf("Error starting server: %s\n", err)
		return err
	}
	fmt.Printf("Server stopped\n")
	return nil
}
