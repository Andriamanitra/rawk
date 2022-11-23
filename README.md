# rawk – the convenience of AWK with full power of Ruby

This is a simple wrapper around Ruby's `eval()` that adds some of the convenient features from AWK, such as auto-initializing variables for each line.


## Examples

### Basic usage
`awk '{print $2}'`

=> `rawk - 'puts A2'`


### Field separator, number of records, number of fields
`awk -F';' '{ print NR,$NF }' file.csv`

=> `rawk file.csv -F';' 'P NR,A[NF-1]'`


### Filtering
`awk '/WARNING/{print $0}'`

=> `rawk - 'puts A0 if A0 =~ /WARNING/'`


### END
`seq 1 5 | awk '{sum += $1} END{print sum}'`

=> `seq 1 5 | rawk - 'sum += N1' -E 'P sum'`
