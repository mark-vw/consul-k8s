package consuldns

import (
	"os"
	"testing"

	testsuite "github.com/hashicorp/consul-k8s/charts/consul/test/acceptance/framework/suite"
)

var suite testsuite.Suite

func TestMain(m *testing.M) {
	suite = testsuite.NewSuite(m)
	os.Exit(suite.Run())
}
