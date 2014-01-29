

export PlusOperator,TimesOperator




type PlusOperator{B<:BandedOperator} <: BandedOperator{Float64} #TODO: Change to T
    ops::Vector{B}
    
    PlusOperator{B}(ops::Vector{B})=new(promotespaces(ops))
end

PlusOperator{B<:BandedOperator}(ops::Vector{B})=PlusOperator{B}(ops)

domainspace(P::PlusOperator)=domainspace(P.ops[1])
rangespace(P::PlusOperator)=rangespace(P.ops[1])

domain(P::PlusOperator)=domain(P.ops)

bandrange(P::PlusOperator)=mapreduce(op->bandrange(op)[1],min,P.ops):mapreduce(op->bandrange(op)[end],max,P.ops)


function addentries!(P::PlusOperator,A::ShiftArray,kr::Range1)
    for op in P.ops
        addentries!(op,A,kr)
    end
    
    A
end


+(A::BandedOperator,B::BandedOperator)=PlusOperator([A,B])
+(A::BandedOperator,f::IFun)=A+MultiplicationOperator(f)
+(f::IFun,A::BandedOperator)=MultiplicationOperator(f)+A
-(A::BandedOperator,f::IFun)=A+MultiplicationOperator(-f)
-(f::IFun,A::BandedOperator)=MultiplicationOperator(f)-A
+(c::Number,A::BandedOperator)=MultiplicationOperator(c)+A
+(A::BandedOperator,c::Number)=A+MultiplicationOperator(c)


type TimesOperator{T<:BandedOperator} <: BandedOperator{Float64} #TODO:Chgange to T
    ops::Vector{T}
    
    function TimesOperator{T}(ops::Vector{T})
        for k=1:length(ops)-1
            @assert domainspace(ops[k])==rangespace(ops[k+1])
        end
        
        new(ops)
    end    
end

TimesOperator{T<:BandedOperator}(ops::Vector{T})=TimesOperator{T}(ops)


domainspace(P::TimesOperator)=domainspace(P.ops[end])
rangespace(P::TimesOperator)=rangespace(P.ops[1])

domain(P::TimesOperator)=domain(P.ops)


bandrange(P::TimesOperator)=mapreduce(x->bandrange(x)[1],+,P.ops):mapreduce(x->bandrange(x)[end],+,P.ops)


##TODO: We keep this around because its faster
## need to unify 
function old_addentries!(P::TimesOperator,A::ShiftArray,kr::Range1)
    kre=kr[1]:(kr[end]+mapreduce(x->bandrange(x)[end],+,P.ops[1:end-1]))

    Z = ShiftArray(zeros(length(kre),size(A,2)),A.colindex,1-kr[1])
    addentries!(P.ops[end],Z,kre)
    
    for j=length(P.ops)-1:-1:1
        krr=kr[1]:(kr[end]+mapreduce(x->bandrange(x)[end],+,P.ops[1:j-1]))    
        multiplyentries!(P.ops[j],Z,krr)
    end
    
    for k=kr,j=columnrange(A)
        A[k,j] += Z[k,j]
    end
    
    A
end

function new_addentries!(P::TimesOperator,A::ShiftArray,kr::Range1)
    krl=Array(Range1,length(P.ops))
    
    krl[1]=kr
    
    for m=1:length(P.ops)-1
      krl[m+1]=indexrange(P.ops[m],krl[m][1])[1]:indexrange(P.ops[m],krl[m][end])[end]
    end
    
    BA=BandedArray(P.ops[end],krl[end])
    
    for m=(length(P.ops)-1):-1:1
      BA=BandedArray(P.ops[m],krl[m])*BA
    end
    
    for k=kr,j=columnrange(BA.data)
        A[k,j] += BA.data[k,j]
    end
    
    A
end

function addentries!(P::TimesOperator,A::ShiftArray,kr::Range1)
    if all(f->typeof(f)<:ConversionOperator,P.ops[1:end-1])
        old_addentries!(P,A,kr)
    else
        new_addentries!(P,A,kr)
    end
end

*(A::TimesOperator,B::TimesOperator)=TimesOperator([A.ops,B.ops])
*(A::TimesOperator,B::BandedOperator)=TimesOperator([A.ops,B])
*(A::BandedOperator,B::TimesOperator)=TimesOperator([A,B.ops])
*(A::BandedOperator,B::BandedOperator)=TimesOperator([A,B])


-(A::BandedOperator)=MultiplicationOperator(-1.,rangespace(A))*A
-(A::BandedOperator,B::BandedOperator)=A+(-B)

*(f::IFun,A::BandedOperator)=MultiplicationOperator(f,rangespace(A))*A
*(c::Number,A::BandedOperator)=MultiplicationOperator(c,rangespace(A))*A



