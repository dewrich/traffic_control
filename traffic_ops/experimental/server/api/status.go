// Copyright 2015 Comcast Cable Communications Management, LLC

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at

// http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// This file was initially generated by gen_to_start.go (add link), as a start
// of the Traffic Ops golang data model

package api

import (
	"encoding/json"
	_ "github.com/Comcast/traffic_control/traffic_ops/experimental/server/output_format" // needed for swagger
	"github.com/jmoiron/sqlx"
	null "gopkg.in/guregu/null.v3"
	"log"
	"time"
)

type Status struct {
	Id          int64       `db:"id" json:"id"`
	Name        string      `db:"name" json:"name"`
	Description null.String `db:"description" json:"description"`
	LastUpdated time.Time   `db:"last_updated" json:"lastUpdated"`
	Links       StatusLinks `json:"_links" db:-`
}

type StatusLinks struct {
	Self string `db:"self" json:"_self"`
}

type StatusLink struct {
	ID  int64  `db:"status" json:"id"`
	Ref string `db:"status_id_ref" json:"_ref"`
}

// @Title getStatusById
// @Description retrieves the status information for a certain id
// @Accept  application/json
// @Param   id              path    int     false        "The row id"
// @Success 200 {array}    Status
// @Resource /api/2.0
// @Router /api/2.0/status/{id} [get]
func getStatusById(id int, db *sqlx.DB) (interface{}, error) {
	ret := []Status{}
	arg := Status{}
	arg.Id = int64(id)
	queryStr := "select *, concat('" + API_PATH + "status/', id) as self "
	queryStr += " from status where id=:id"
	nstmt, err := db.PrepareNamed(queryStr)
	err = nstmt.Select(&ret, arg)
	if err != nil {
		log.Println(err)
		return nil, err
	}
	nstmt.Close()
	return ret, nil
}

// @Title getStatuss
// @Description retrieves the status
// @Accept  application/json
// @Success 200 {array}    Status
// @Resource /api/2.0
// @Router /api/2.0/status [get]
func getStatuss(db *sqlx.DB) (interface{}, error) {
	ret := []Status{}
	queryStr := "select *, concat('" + API_PATH + "status/', id) as self "
	queryStr += " from status"
	err := db.Select(&ret, queryStr)
	if err != nil {
		log.Println(err)
		return nil, err
	}
	return ret, nil
}

// @Title postStatus
// @Description enter a new status
// @Accept  application/json
// @Param                 Body body     Status   true "Status object that should be added to the table"
// @Success 200 {object}    output_format.ApiWrapper
// @Resource /api/2.0
// @Router /api/2.0/status [post]
func postStatus(payload []byte, db *sqlx.DB) (interface{}, error) {
	var v Status
	err := json.Unmarshal(payload, &v)
	if err != nil {
		log.Println(err)
		return nil, err
	}
	sqlString := "INSERT INTO status("
	sqlString += "name"
	sqlString += ",description"
	sqlString += ") VALUES ("
	sqlString += ":name"
	sqlString += ",:description"
	sqlString += ")"
	result, err := db.NamedExec(sqlString, v)
	if err != nil {
		log.Println(err)
		return nil, err
	}
	return result, err
}

// @Title putStatus
// @Description modify an existing statusentry
// @Accept  application/json
// @Param   id              path    int     true        "The row id"
// @Param                 Body body     Status   true "Status object that should be added to the table"
// @Success 200 {object}    output_format.ApiWrapper
// @Resource /api/2.0
// @Router /api/2.0/status/{id}  [put]
func putStatus(id int, payload []byte, db *sqlx.DB) (interface{}, error) {
	var v Status
	err := json.Unmarshal(payload, &v)
	v.Id = int64(id) // overwrite the id in the payload
	if err != nil {
		log.Println(err)
		return nil, err
	}
	v.LastUpdated = time.Now()
	sqlString := "UPDATE status SET "
	sqlString += "name = :name"
	sqlString += ",description = :description"
	sqlString += ",last_updated = :last_updated"
	sqlString += " WHERE id=:id"
	result, err := db.NamedExec(sqlString, v)
	if err != nil {
		log.Println(err)
		return nil, err
	}
	return result, err
}

// @Title delStatusById
// @Description deletes status information for a certain id
// @Accept  application/json
// @Param   id              path    int     false        "The row id"
// @Success 200 {array}    Status
// @Resource /api/2.0
// @Router /api/2.0/status/{id} [delete]
func delStatus(id int, db *sqlx.DB) (interface{}, error) {
	arg := Status{}
	arg.Id = int64(id)
	result, err := db.NamedExec("DELETE FROM status WHERE id=:id", arg)
	if err != nil {
		log.Println(err)
		return nil, err
	}
	return result, err
}
