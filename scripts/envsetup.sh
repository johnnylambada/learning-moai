function hmm() {
cat <<EOF
Invoke ". scripts/envsetup.sh" from your shell to add the following 
functions to your environment:
EOF
    T=$(gettop)
    sort $T/.hmm |awk -F @ '{printf "%-15s %s\n",$1,$2}'
cat <<EOF

You'll also get the following environment variables:
EOF
    sort $T/.hmmv |awk -F @ '{printf "%-15s %s\n",$1,$2}'
}

function gettop
{
    local TOPFILE=scripts/envsetup.sh
    if [ -n "$TOP" -a -f "$TOP/$TOPFILE" ] ; then
        echo $TOP
    else
        if [ -f $TOPFILE ] ; then
            # The following circumlocution (repeated below as well) ensures
            # that we record the true directory name and not one that is
            # faked up with symlink names.
            PWD= /bin/pwd
        else
            # We redirect cd to /dev/null in case it's aliased to
            # a command that prints something as a side-effect
            # (like pushd)
            local HERE=$PWD
            T=
            while [ \( ! \( -f $TOPFILE \) \) -a \( $PWD != "/" \) ]; do
                cd .. > /dev/null
                T=`PWD= /bin/pwd`
            done
            cd $HERE > /dev/null
            if [ -f "$T/$TOPFILE" ]; then
                echo $T
            fi
        fi
    fi
}
T=$(gettop)
rm -f $T/.hmm $T/.hmmv
echo "gettop@display the top directory" >> $T/.hmm

function croot()
{
    T=$(gettop)
    if [ "$T" ]; then
        cd $(gettop)
    else
        echo "Couldn't locate the top of the tree.  Try setting TOP."
    fi
}
echo "croot@Change back to the top dir" >> $T/.hmm

function moais()
{
    find $(gettop)/bin -name moai -type f
}
echo "moais@Show possible moai apps" >> $T/.hmm

unset T f
