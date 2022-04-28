package main

import (
	"context"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"strconv"

	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
	"goji.io/pat"
	"gopkg.in/yaml.v3"

	// "github.com/goji/httpauth"
	"goji.io"
)

type ShrlSettings struct {
	BaseURL               string
	Port                  int
	DefaultRedirect       string
	UploadDirectory       string
	MongoConnectionString string
	AdminUsername         string
	AdminPassword         string

	SettingsFilepath       string
	ResolveLocationHosts   []string `yaml:"resolveLocation"`
	StripQueryParamsHosts  []string `yaml:"stripQueryParams"`
	TerminalRedirect       bool     `yaml:"terminalRedirect"`
	TerminalRedirectString string   `yaml:"terminalRedirectString"`
}

func (s *ShrlSettings) Parse(data []byte) error {
	return yaml.Unmarshal(data, s)
}

var (
	collection *mongo.Collection
	ctx        = context.TODO()
)

var Settings ShrlSettings

func init() {
	// Init Settings
	port, err := strconv.Atoi(os.Getenv("SHRLS_PORT"))
	if err != nil {
		log.Fatal(fmt.Sprintf("Invalid Port: %s", err))
		os.Exit(1)
	}

	Settings = ShrlSettings{
		BaseURL:         os.Getenv("SHRLS_BASE_URL"),
		Port:            port,
		DefaultRedirect: os.Getenv("DEFAULT_REDIRECT"),
		UploadDirectory: os.Getenv("UPLOAD_DIRECTORY"),
		// mongodb://mongo:example@localhost:27017
		MongoConnectionString: os.Getenv("MONGO_URI"),
		AdminUsername:         os.Getenv("SHRLS_USERNAME"),
		AdminPassword:         os.Getenv("SHRLS_PASSWORD"),
		SettingsFilepath:      os.Getenv("SHRLS_SETTINGS_FILE"),
		TerminalRedirect:      false,
	}

	if Settings.SettingsFilepath != "" {
		b, err := ioutil.ReadFile(Settings.SettingsFilepath)
		if err != nil {
			log.Fatal(fmt.Sprintf("Error reading settings file %s, %s", Settings.SettingsFilepath, err))
			os.Exit(1)
		}

		Settings.Parse(b)
	}

	log.Printf("Loaded settings: %#v", Settings)

	// Init Mongo
	clientOptions := options.Client().ApplyURI(Settings.MongoConnectionString)
	client, err := mongo.Connect(ctx, clientOptions)
	if err != nil {
		log.Fatal(err)
	}

	err = client.Ping(ctx, nil)
	if err != nil {
		log.Fatal(err)
	}

	collection = client.Database("shrls").Collection("urls")
}

func main() {
	workdir, err := os.Getwd()
	if err != nil {
		log.Fatal(fmt.Sprintf("Error %s", err))
		os.Exit(1)
	}

	mux := goji.NewMux()
	admin_mux := goji.SubMux()
	api_mux := goji.SubMux()
	shrl_mux := goji.SubMux()
	curl_api_mux := goji.SubMux()

	// if Settings.AdminUsername != "" && Settings.AdminPassword != "" {
	// 	authOpts := httpauth.AuthOptions{
	// 		User:                Settings.AdminUsername,
	// 		Password:            Settings.AdminPassword,
	// 		UnauthorizedHandler: http.HandlerFunc(UnauthorizedWarning),
	// 	}
	// 	auth_middleware := httpauth.BasicAuth(authOpts)
	// 	api_mux.Use(auth_middleware)
	// 	admin_mux.Use(auth_middleware)
	// 	curl_api_mux.Use(auth_middleware)
	// }

	// Api
	mux.Handle(pat.New("/api/*"), api_mux)
	api_mux.HandleFunc(pat.Get("/shrl/:shrl"), urlPrintInfo)
	api_mux.HandleFunc(pat.Get("/shrl"), urlPrintAll)
	api_mux.HandleFunc(pat.Put("/shrl/:shrl_id"), urlModify)
	api_mux.HandleFunc(pat.Delete("/shrl/:shrl_id"), urlDelete)
	api_mux.HandleFunc(pat.Post("/shrl"), urlNew)

	// Frontend
	// mux.HandleFunc(pat.Get("/"), defaultRedirect)
	mux.Handle(pat.New("/shrl/*"), shrl_mux)
	shrl_mux.HandleFunc(pat.Get("/:shrl"), resolveShrl)
	shrl_mux.HandleFunc(pat.Get("/:shrl/:search"), resolveShrl)

	// Admin
	mux.Handle(pat.New("/*"), admin_mux)
	fs := http.FileServer(http.Dir(workdir + "/dist/"))
	// admin_mux.Handle(pat.Get("/*"), http.StripPrefix("/admin/", fs))
	admin_mux.Handle(pat.Get("/*"), fs)

	// Bookmarklet API
	api_mux.HandleFunc(pat.Get("/bookmarklet/new"), bookmarkletNew)

	// File Uploads
	api_mux.HandleFunc(pat.Post("/upload"), fileUpload)

	// Snippets
	api_mux.HandleFunc(pat.Post("/snippet"), snippetUpload)
	api_mux.HandleFunc(pat.Get("/snippet/:snippet_id"), snippetGet)

	// Curl API
	mux.Handle(pat.New("/*"), curl_api_mux)
	curl_api_mux.HandleFunc(pat.Post("/"), curlNew)

	http.ListenAndServe(fmt.Sprintf("0.0.0.0:%d", Settings.Port), mux)
}
