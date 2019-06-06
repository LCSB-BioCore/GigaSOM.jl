# print out the version and the architecture
echo "ARCH = $ARCH"
echo "JULIA_VER = $JULIA_VER"

# launch the test script
if [ "$ARCH" == "Linux" ]; then
    $ARTENOLIS_SOFT_PATH/julia/$JULIA_VER/bin/julia --color=yes -e 'import Pkg; Pkg.clone(pwd()); Pkg.test("GigaSOM", coverage=true); Pkg.rm("GigaSOM");'
fi

CODE=$?
exit $CODE
